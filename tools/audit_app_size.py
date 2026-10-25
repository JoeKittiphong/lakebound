"""Audit existing Android archives; estimates are not replacement signed APKs."""
from pathlib import Path
from zipfile import ZipFile
from collections import defaultdict
import json
import zlib

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "exports/size-audit"


def audit(path: Path) -> dict:
    report = {"archive": path.name, "archive_bytes": path.stat().st_size, "groups": {}, "largest": []}
    with ZipFile(path) as archive:
        entries = archive.infolist()
        groups = defaultdict(lambda: {"stored_bytes": 0, "uncompressed_bytes": 0, "entries": 0})
        for entry in entries:
            name = entry.filename
            key = "native/" + name.split("/")[-2] if name.endswith(".so") else ("assets" if "/assets/" in name or name.startswith("assets/") else "other")
            groups[key]["stored_bytes"] += entry.compress_size
            groups[key]["uncompressed_bytes"] += entry.file_size
            groups[key]["entries"] += 1
        report["groups"] = dict(groups)
        report["largest"] = [{"path": i.filename, "stored_bytes": i.compress_size, "uncompressed_bytes": i.file_size} for i in sorted(entries, key=lambda i: i.compress_size, reverse=True)[:20]]
        if path.suffix == ".apk":
            native = defaultdict(int)
            for entry in entries:
                if not entry.filename.endswith(".so"):
                    continue
                compressor = zlib.compressobj(6, zlib.DEFLATED, -15)
                size = 0
                with archive.open(entry) as source:
                    while chunk := source.read(1024 * 1024):
                        size += len(compressor.compress(chunk))
                size += len(compressor.flush())
                native[entry.filename.split("/")[-2]] += size
            other = sum(i.compress_size for i in entries if not i.filename.endswith(".so"))
            report["payload_estimates_not_built_apks"] = {
                "basis": "Same existing APK payload, recompressing native .so only at DEFLATE level 6; excludes signing/ZIP alignment overhead and future content changes.",
                "compressed_universal_bytes": other + sum(native.values()),
                "compressed_arm64_only_bytes": other + native["arm64-v8a"],
                "compressed_native_by_abi": dict(native),
            }
    return report


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    names = ["lakebound-fishing-playtest.apk", "lakebound-0.1.0-internal.aab", "lakebound-0.1.8-closed.aab"]
    reports = [audit(ROOT / "exports/android" / name) for name in names if (ROOT / "exports/android" / name).exists()]
    (OUTPUT / "archives.json").write_text(json.dumps(reports, indent=2), encoding="utf-8")
    for report in reports:
        print(report["archive"], round(report["archive_bytes"] / 1048576, 2), "MiB", report["groups"])
        if "payload_estimates_not_built_apks" in report:
            print("ESTIMATES ONLY", report["payload_estimates_not_built_apks"])


if __name__ == "__main__":
    main()
