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
HEADLESS = ("fishing_recovery", "boat_integration", "traversal_equipment", "character_integration", "walk_sync", "playtest_feedback", "export_size", "ui_atlas", "missions", "economy", "expansion_flow", "first_catch_tutorial", "startup_flow", "camera_movement", "bait_retrieval", "tension_haptics", "fish_behavior", "fishing_simulation", "fish_catalog_fishing", "fish_models", "refactor_boundaries")
RENDER = ("fishing_recovery_visual", "fisherman_visual", "ui_atlas_visual", "missions_visual", "expansion_visual", "collection", "mobile_collection", "mobile_multitouch", "fishing_visual", "active_scene_movement", "rod_tension", "fish_render", "water_render", "water_interactions", "water_optimization")
HEADLESS += ("hud_session", "loading_flow", "fish_encyclopedia", "regions_fishing", "regions_legacy_save", "wooden_jetty_integration", "mobile_fishing_tuning")
SLOW_HEADLESS = ("river_integration",)  # Walks the full river loop at production speed.
RENDER += ("regions_integration", "loading_cinematic_visual", "character_preview", "mobile_refinements", "mobile_fishing_visual", "walk_visual", "river_render")
# Asset authoring checks are opt-in; unlike gameplay regression they may need
# source art/tool outputs and a renderer. Packed checks require an artifact.
CONTENT = ("aquatic", "background", "dense_flora", "bridge_normal_visual", "concept_rocks", "reference_rocks", "rock_asset", "rock_clusters", "rock_landscaping")
PACKED = ("packed_size", "packed_memory_smoke")
SOURCE_TESTS = HEADLESS + SLOW_HEADLESS + RENDER + CONTENT
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
    parser.add_argument("--suite", choices=("headless", "slow", "render", "content", "all"), default="headless")
    parser.add_argument("--tests", nargs="+", choices=SOURCE_TESTS, help="Run selected source tests instead of a whole suite")
    parser.add_argument("--list", action="store_true", help="List registered tests without starting Godot")
    parser.add_argument("--rendering-method", choices=("mobile", "gl_compatibility", "forward_plus"), help="Explicit renderer for GPU tests")
    parser.add_argument("--output", type=Path, default=ROOT / "exports/qa")
    parser.add_argument("--timeout", type=float, default=120, help="Seconds per process")
    parser.add_argument("--android-pack", type=Path, help="Also check an existing Android PCK for exported UI and touch regressions")
    args = parser.parse_args()
    if args.list:
        for group, tests in (("headless", HEADLESS), ("slow/headless", SLOW_HEADLESS), ("render", RENDER), ("content", CONTENT), ("packed (artifact required)", PACKED)):
            print(f"{group}: {', '.join(tests)}")
        registered = set(SOURCE_TESTS + PACKED)
        found = {path.stem.removesuffix("_test") for path in (ROOT / "tests").glob("*_test.gd")}
        missing = sorted(found - registered)
        stale = sorted(registered - found)
        if missing:
            print(f"Unregistered: {', '.join(missing)}")
        if stale:
            print(f"Missing files: {', '.join(stale)}")
        return 1 if missing or stale else 0
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
    results = []

    def run(name: str, command: list[str]) -> None:
        log = output / f"{name}.console.log"
        # Every process gets its own user:// data. A tutorial/profile written by
        # one suite must not decide the initial state of a later suite.
        test_env = env.copy()
        if os.name == "nt":
            for variable, folder in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
                directory = output / "profiles" / name / folder
                directory.mkdir(parents=True, exist_ok=True)
                test_env[variable] = str(directory)
        with subprocess.Popen(command, cwd=ROOT, env=test_env, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, encoding="utf-8", errors="replace",
                              creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0) as process:
            try:
                stdout, stderr = process.communicate(timeout=args.timeout)
                text = stdout + stderr
                code = process.returncode
            except subprocess.TimeoutExpired:
                # The Windows console executable can own a child engine process.
                # Kill the owned tree before reaping the parent, or a timed-out
                # suite can keep running and alter later fixtures/screenshots.
                if os.name == "nt":
                    subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                   capture_output=True, timeout=10,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
                process.kill()
                stdout, stderr = process.communicate(timeout=10)
                text = stdout + stderr + f"\nTIMEOUT after {args.timeout}s\n"
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
        if args.suite in ("slow", "all"):
            suites += [(test, True) for test in SLOW_HEADLESS]
        if args.suite in ("render", "all"):
            suites += [(test, False) for test in RENDER]
        if args.suite in ("content", "all"):
            suites += [(test, False) for test in CONTENT]
        if args.tests:
            suites = [(test, test in HEADLESS + SLOW_HEADLESS) for test in dict.fromkeys(args.tests)]
        for test, headless in suites:
            command = [args.godot, "--path", str(ROOT), "--log-file", str(output / f"{test}.log")]
            if headless:
                command += ["--headless"]
            elif args.rendering_method:
                command += ["--rendering-method", args.rendering_method]
            command += ["--script", f"res://tests/{test}_test.gd"]
            run(test, command)
        if args.android_pack:
            for test in ("startup_flow", "mobile_collection", "mobile_multitouch"):
                run(f"packed_{test}", [args.godot, "--main-pack", str(args.android_pack.resolve()),
                    "--log-file", str(output / f"packed_{test}.log"),
                    "--script", str(ROOT / f"tests/{test}_test.gd")])
    (output / "results.json").write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    sys.exit(main())
