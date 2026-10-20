# Android App Bundle export

Use Godot 4.7.2. Open **Project > Export** and select **Android AAB**. The existing **Android** preset is preserved separately.

## Preset

- Format: Android App Bundle (.aab), Gradle enabled.
- Output: `exports/android/lakebound.aab`.
- App name: Lakebound.
- Package ID: `com.zylaah.lakebound` (provisional; confirm before first publication).
- Version name/code: `0.1.0` / `1`. Increase the code for each uploaded update.
- ARM64 and ARMv7 enabled; x86 disabled.
- Minimum API 28 (Android 9), target API 36, matching the installed 4.7.2 build template.
- Landscape orientation, immersive display, edge-to-edge and responsive scene UI.
- Android ETC2/ASTC texture import enabled.
- No Internet, storage, location, or microphone permissions requested by this prototype.
- Launcher icon uses `shared/branding/icon.png`, with Android adaptive foreground/background assets.

## Local toolchain

Godot Editor Settings already point to these installed tools:

- Java SDK: `C:/Users/Zylaah/programmer/godot/Bone2D/.runtime/android/jdk-17.0.20.1+1`
- Android SDK: `C:/Users/Zylaah/programmer/godot/Bone2D/.runtime/android/sdk`

The project-local Gradle source is installed in `android/build` from the official installed `4.7.2.stable/android_source.zip`. The export preset's Gradle directory is its parent, `res://android`.

`android/` and `exports/` are ignored in Git. On another machine, install the matching Godot export templates and use **Project > Install Android Build Template** before exporting.

## Debug build

For a build check, enable **Export With Debug** and save as `exports/android/lakebound-debug.aab`. The command-line equivalent is:

```powershell
$env:GRADLE_USER_HOME = 'C:\Users\Zylaah\programmer\godot\Bone2D\.runtime\android\gradle-cache'
& 'C:\Users\Zylaah\programmer\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:\Users\Zylaah\programmer\mobile game\fishing game\fishing-game' --export-debug 'Android AAB' 'exports/android/lakebound-debug.aab'
```

The cache override reuses already installed Gradle dependencies; it is only needed for this machine's command-line convenience. Godot obtains Java/Android SDK locations from Editor Settings.

### Verified output

`exports/android/lakebound-debug.aab` was built successfully (about 61.2 MB). ZIP integrity, BundleConfig, base manifest, ARM64/ARMv7 libraries, package ID, game category, landscape orientation, and target API 36 were checked. `jarsigner -verify` reports this particular debug artifact is unsigned; it is a build-validation artifact, not a Play-ready signed release. Signing is still required for publication. No release keystore was created, selected, or reused.

## Google Play release signing

Before a Play upload, configure **Keystore > Release**, **Release User** (key alias), and **Release Password** using your own upload keystore, then disable **Export With Debug**. A successful debug build does not replace release signing or device testing.

Run `tools/build_release.ps1` to build the signed release. The dedicated Lakebound upload key is in the Git-ignored `signing/` folder. Its password is protected with Windows DPAPI and is readable only by the Windows account that generated it. The script supplies Godot signing variables only for the build and clears them afterward. Never commit this folder. Back up the key and recoverable password securely before moving to another machine; the DPAPI file alone is not portable. The output is `exports/android/lakebound-0.1.0-internal.aab`.

Validation: `tools/capture_release.gd` captures real rendered scenes and smoke-tests menu/play/movement/Android-back behavior. `tools/verify_release.py` checks bundle ZIP integrity, exclusion of signing material, release manifest, ARM64 ELF 16 KB segment alignment, and Play asset dimensions. Results are in `exports/play-store/validation.json`. These checks do not replace Play server validation or physical Android device testing.

An AAB is intended for store/bundle tooling; use an APK export to install a standalone package directly on a phone.

References: [Godot Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html), [Gradle builds](https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html).

## Upload key created and verified

The upload keystore is `.signing/lakebound-upload.jks`, alias `lakebound-upload`. Local Release fields are configured for both Android presets in `.godot/export_credentials.cfg`. The password is in `.signing/release-credentials.txt` and its JSON companion. These files are ignored by Git. Securely back up the keystore and password; use the same upload identity for updates.

Signed release output: `exports/android/lakebound-signed-release.aab` (about 57.9 MB). Export succeeded, signature verification passed, the signer matches the new upload keystore, ZIP integrity passed, and the release manifest is not debuggable. No Play Console upload was performed. The `tools/build_release.ps1` helper now reuses this keystore.
