"""Build an isolated release-mode AAB with a QA-only signing identity.

Never uploads anything or reads a production signing key. Paths are supplied
explicitly; use a staged project and a temporary QA key under ignored exports/.
"""
from pathlib import Path
import argparse
import json
import os
import subprocess


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("project", "output", "godot", "java-home", "sdk", "gradle-cache", "qa-key", "profile"):
        p.add_argument("--" + name, type=Path, required=True)
    args = p.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update({"APPDATA": str(args.profile / "roaming"), "LOCALAPPDATA": str(args.profile / "local"),
                "JAVA_HOME": str(args.java_home), "ANDROID_HOME": str(args.sdk), "ANDROID_SDK_ROOT": str(args.sdk),
                "GRADLE_USER_HOME": str(args.gradle_cache), "GODOT_ANDROID_KEYSTORE_RELEASE_PATH": str(args.qa_key.resolve()),
                "GODOT_ANDROID_KEYSTORE_RELEASE_USER": "androiddebugkey", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD": "android"})
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    command = [str(args.godot), "--path", str(args.project.resolve()), "--rendering-method", "gl_compatibility",
               "--log-file", str(output.parent / "qa-aab-build.log"), "--export-release", "Android AAB", str(output)]
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env,
                               startupinfo=startup, creationflags=subprocess.CREATE_NO_WINDOW)
    try:
        data, _ = process.communicate(timeout=240)
        result = {"exit": process.returncode, "timeout": False}
    except subprocess.TimeoutExpired:
        process.kill()
        data, _ = process.communicate(timeout=10)
        result = {"exit": process.returncode, "timeout": True}
    (output.parent / "qa-aab-console.log").write_bytes(data)
    result["aab_bytes"] = output.stat().st_size if output.exists() else None
    result["qa_only"] = True
    (output.parent / "qa-aab-result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result), flush=True)
    # Keep output concise and avoid printing any environment or signing data.
    print(data.decode("utf-8", errors="replace")[-1800:], flush=True)
    return 0 if process.returncode == 0 and output.exists() else 1


if __name__ == "__main__":
    raise SystemExit(main())
