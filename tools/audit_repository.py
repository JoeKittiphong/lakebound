"""Check Git publication candidates without reading ignored credentials or caches."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = re.compile(
    r"(^|/)(?:\.godot|android|exports|signing|\.signing|\.venv|node_modules|user_data)(/|$)"
    r"|(^|/)(?:\.env(?:\..*)?|release-credentials\.json|id_rsa|id_ed25519)$"
    r"|\.(?:jks|keystore|dpapi|p12|pfx|pem|key|apk|aab|apks|pck|pyc|tmp|bak)$",
    re.IGNORECASE,
)
SECRETS = {
    "private_key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "github_token": re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,})"),
    "google_api_key": re.compile(r"AIza[\w-]{30,}"),
    "aws_access_key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "literal_secret": re.compile(
        r'''(?im)^\s*(?:password|token|secret|api_key|release_password)\s*[=:]\s*["'][^"'\r\n]{8,}["']'''
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    # Includes already tracked files, so a new ignore cannot conceal an old leak.
    names = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=ROOT
    ).decode("utf-8").split("\0")
    findings: list[dict] = []
    files: list[tuple[int, str]] = []
    for name in sorted(set(filter(None, names))):
        path = ROOT / name
        if not path.is_file():
            continue  # Working-tree deletions are not publication candidates.
        size = path.stat().st_size
        files.append((size, name))
        if name != ".env.example" and FORBIDDEN.search(name):
            findings.append({"path": name, "rule": "excluded_artifact_or_private_file"})
        if size >= 100 * 1024 * 1024:
            findings.append({"path": name, "rule": "github_100_MiB_limit"})
        if size > 3_000_000:
            continue
        raw = path.read_bytes()
        if b"\0" in raw:
            continue
        try:
            content = raw.decode("utf-8")
        except UnicodeDecodeError:
            continue
        for rule, pattern in SECRETS.items():
            if pattern.search(content):
                findings.append({"path": name, "rule": rule})
    report = {
        "files": len(files), "bytes": sum(size for size, _ in files),
        "largest_files": [{"path": name, "bytes": size} for size, name in sorted(files, reverse=True)[:10]],
        "findings": findings,
        "scope": "Working-tree publication candidates; known secret patterns in UTF-8 files up to 3 MB. Not a full-history content scan.",
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
