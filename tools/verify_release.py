"""Verify an explicit Android bundle, same-build manifest, and artwork."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import struct
import subprocess
import xml.etree.ElementTree as ET
import zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ANDROID = "{http://schemas.android.com/apk/res/android}"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("aab", type=Path, help="Exact bundle to verify")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--manifest", type=Path, help="XML manifest from this exact build")
    source.add_argument("--bundletool", type=Path, help="Read manifest directly from the AAB using this JAR")
    parser.add_argument("--java", default="java")
    parser.add_argument("--artwork-dir", type=Path, default=ROOT / "exports/play-store")
    parser.add_argument("--report", type=Path, default=ROOT / "exports/play-store/validation.json")
    parser.add_argument("--qa-dir", type=Path)
    args = parser.parse_args()
    aab = args.aab.resolve()
    if args.bundletool:
        result = subprocess.run([args.java, "-jar", str(args.bundletool), "dump", "manifest",
                                 "--bundle=" + str(aab), "--module=base"],
                                check=True, capture_output=True, text=True, encoding="utf-8", timeout=60)
        manifest = ET.fromstring(result.stdout)
        manifest_source = "bundletool: " + str(aab)
    else:
        manifest = ET.parse(args.manifest).getroot()
        manifest_source = str(args.manifest.resolve())
    version = re.search(r'^config/version="([^"]+)"',
                        (ROOT / "project.godot").read_text(encoding="utf-8-sig"), re.M).group(1)
    require(manifest.attrib["package"] == "com.zylaah.lakebound", "Unexpected package identity")
    require(manifest.attrib[ANDROID + "versionName"] == version, "Manifest version differs from project.godot")
    require(manifest.find("uses-sdk").attrib[ANDROID + "targetSdkVersion"] == "36", "Unexpected target SDK")
    require(manifest.find("application").attrib.get(ANDROID + "debuggable", "false") == "false", "Debug build")
    permissions = [el.attrib.get(ANDROID + "name") for el in manifest.findall("uses-permission")]
    require(set(permissions) <= {"android.permission.VIBRATE"}, "Unexpected permissions: " + str(permissions))
    libraries = {}
    with zipfile.ZipFile(aab) as bundle:
        require(bundle.testzip() is None, "Corrupt AAB ZIP entry")
        names = bundle.namelist()
        forbidden = [name for name in names if any(part in name.lower() for part in
                     ("/signing/", "/.signing/", ".jks", ".dpapi", "release-credentials", "/tools/",
                      "/tests/", "/docs/", "/exports/", "feature-source", "icon-source"))]
        require(not forbidden, "Unwanted files in bundle: " + str(forbidden))
        require(any(name.startswith("META-INF/") and name.endswith(".RSA") for name in names), "Missing signature entry")
        for name in names:
            if not (name.startswith("base/lib/arm64-v8a/") and name.endswith(".so")):
                continue
            data = bundle.read(name)
            require(data[:5] == b"\x7fELF\x02", "Not an ELF64 library: " + name)
            phoff = struct.unpack_from("<Q", data, 32)[0]
            entry_size, count = struct.unpack_from("<HH", data, 54)
            alignments = []
            for index in range(count):
                entry = phoff + index * entry_size
                if struct.unpack_from("<I", data, entry)[0] == 1:
                    alignment = struct.unpack_from("<Q", data, entry + 48)[0]
                    require(alignment >= 16384, "ELF alignment below 16KB: " + name)
                    alignments.append(alignment)
            require(bool(alignments), "No loadable segments: " + name)
            libraries[name] = alignments
    require(bool(libraries), "No ARM64 libraries")
    assets = {}
    for name, size in (("icon-512.png", (512, 512)), ("feature-1024x500.png", (1024, 500)),
                       ("01-menu.png", (1280, 720)), ("02-lakeside.png", (1280, 720)), ("03-dock.png", (1280, 720))):
        path = args.artwork_dir / name
        with Image.open(path) as image:
            require(image.size == size, "Unexpected artwork dimensions: " + name)
            assets[name] = {"size": image.size, "mode": image.mode, "bytes": path.stat().st_size}
    report = {"package": manifest.attrib["package"], "version": version,
              "version_code": int(manifest.attrib[ANDROID + "versionCode"]),
              "target_sdk": int(manifest.find("uses-sdk").attrib[ANDROID + "targetSdkVersion"]),
              "min_sdk": int(manifest.find("uses-sdk").attrib[ANDROID + "minSdkVersion"]),
              "aab": str(aab), "aab_bytes": aab.stat().st_size,
              "sha256": hashlib.sha256(aab.read_bytes()).hexdigest(), "permissions": permissions,
              "manifest_source": manifest_source, "arm64_load_segment_alignment": libraries,
              "assets": assets, "qa_directory": str(args.qa_dir.resolve()) if args.qa_dir else None,
              "limitations": ["No physical Android device or Google Play validation performed",
                              "Signature entry presence checked; certificate validity not verified"]}
    if args.manifest:
        report["limitations"].append("Caller must supply the XML manifest from the selected AAB build")
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
