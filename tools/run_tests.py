"""Run Godot regression suites with bounded processes and isolated artifacts."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
HEADLESS = ("economy", "expansion_flow", "first_catch_tutorial", "startup_flow", "camera_movement", "bait_retrieval", "tension_haptics", "fish_behavior", "fishing_simulation", "fish_catalog_fishing", "fish_models", "refactor_boundaries")
RENDER = ("expansion_visual", "collection", "mobile_collection", "mobile_multitouch", "fishing_visual", "active_scene_movement", "rod_tension", "fish_render", "water_render", "water_interactions", "water_optimization")
# These host/sandbox diagnostics do not concern game scripts; keep them in logs
# and report them separately instead of treating every successful exit as proof.
HOST_DIAGNOSTICS = (
    "Failed to read the root certificate store.",
    "Failed to open log file for writing:",
    "Could not create directory: 'user://",
    "Can't create shader cache folder",
    "Can't save resource to empty path.",
    "Error saving editor settings to",
    "Cannot go into subdir 'signing'.",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("LAKEBOUND_GODOT") or shutil.which("godot"))
    parser.add_argument("--suite", choices=("headless", "render", "all"), default="headless")
    parser.add_argument("--output", type=Path, default=ROOT / "exports/qa")
    parser.add_argument("--timeout", type=float, default=120, help="Seconds per process")
    parser.add_argument("--android-pack", type=Path, help="Also check an existing Android PCK for exported UI and touch regressions")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Set LAKEBOUND_GODOT, pass --godot, or add godot to PATH")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    screenshots = output / "screenshots"
    screenshots.mkdir(exist_ok=True)
    env = os.environ.copy()
    env["LAKEBOUND_QA_DIR"] = screenshots.as_posix()
    # Keep engine caches and user:// test data inside the selected QA directory.
    if os.name == "nt":
        for variable, folder in (("APPDATA", "profile/roaming"), ("LOCALAPPDATA", "profile/local")):
            directory = output / folder
            directory.mkdir(parents=True, exist_ok=True)
            env[variable] = str(directory)
    results = []

    def run(name: str, command: list[str]) -> None:
        log = output / f"{name}.console.log"
        try:
            completed = subprocess.run(command, cwd=ROOT, env=env, capture_output=True,
                                       timeout=args.timeout, encoding="utf-8", errors="replace",
                                       creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
            text = completed.stdout + completed.stderr
            code = completed.returncode
        except subprocess.TimeoutExpired as error:
            chunks = (error.stdout or b"", error.stderr or b"")
            text = "\n".join(x.decode("utf-8", "replace") if isinstance(x, bytes) else x for x in chunks)
            text += f"\nTIMEOUT after {args.timeout}s\n"
            code = -1
        log.write_text(text, encoding="utf-8")
        diagnostics = [line for line in text.splitlines() if re.search(r"(?:SCRIPT ERROR:|ERROR:|FAIL:)", line)]
        warnings = [line for line in diagnostics if any(known in line for known in HOST_DIAGNOSTICS)]
        errors = [line for line in diagnostics if line not in warnings]
        marker = name == "import" or bool(re.search(r"(?:RESULT:|RESULT\s*:)", text))
        ok = code == 0 and not errors and marker
        results.append({"test": name, "passed": ok, "exit_code": code, "errors": errors,
                        "host_diagnostics": warnings,
                        "warnings": [line for line in text.splitlines() if line.startswith("WARNING:")],
                        "log": str(log)})
        print(f"{'PASS' if ok else 'FAIL'} {name} (exit={code}, host diagnostics={len(warnings)})", flush=True)
        for line in errors[:5]:
            print(line, flush=True)

    run("import", [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(output / "import.log"),
                   "--editor", "--import", "--quit"])
    if results[-1]["passed"]:
        suites = []
        if args.suite in ("headless", "all"):
            suites += [(test, True) for test in HEADLESS]
        if args.suite in ("render", "all"):
            suites += [(test, False) for test in RENDER]
        for test, headless in suites:
            command = [args.godot, "--path", str(ROOT), "--log-file", str(output / f"{test}.log")]
            if headless:
                command += ["--headless"]
            command += ["--script", f"res://tests/{test}_test.gd"]
            run(test, command)
        if args.android_pack:
            for test in ("mobile_collection", "mobile_multitouch"):
                run(f"packed_{test}", [args.godot, "--main-pack", str(args.android_pack.resolve()),
                    "--log-file", str(output / f"packed_{test}.log"),
                    "--script", str(ROOT / f"tests/{test}_test.gd")])
    (output / "results.json").write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    sys.exit(main())
