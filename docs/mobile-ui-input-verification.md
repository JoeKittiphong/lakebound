# Mobile collection and simultaneous controls — 21 October 2026

The journal now fills the display after Android binary scene export, and separate fingers can own walking and camera movement in either press order.

## Fixes

- Explicitly anchor the CollectionPanel instance inside FishingHUD. Its exported instance previously had zero size and zero anchors, even though the source scene looked correct. This was reproduced using the resources from the shipped 0.1.6 AAB, without modifying that bundle.
- Give the scroll area and grid explicit minimum extents. Reflow columns and card heights when opening, becoming visible, or resizing, including while gameplay is paused.
- Real touches supersede stale emulated mouse ownership. Mobile joystick and camera handlers ignore mouse duplicates; desktop forwarded mouse controls remain supported.
- Keep finger ownership independent across release, cancellation, repeated presses and app interruptions. A canceled rod gesture resets without emitting a cast release.

## Regression coverage

`mobile_collection_test.gd` checks all 16 cards, textures, usable card dimensions, full-display modal bounds, first and last rows, repeated opens, pause/resume and five viewport sizes: 1280×720, 2400×1080, 2340×1080, 960×540 and 720×1280. It includes opening before the first rendered frame.

`mobile_multitouch_test.gd` checks both press orders, emulated mouse arriving before or after touches, release/repress while the other control remains active, reused finger indices, cancellation, third fingers and focus/app pause recovery at three landscape resolutions.

The runner accepts an existing Android resource pack so these tests also exercise exported binary scenes and scripts, rather than only the source project:

```powershell
python tools/run_tests.py --godot <Godot-console-executable> --suite all --android-pack exports/qa-mobile-fixes/mobile.pck --output exports/qa-mobile-fixes/final --timeout 90
```

The pack is created locally with `--headless --path . --export-pack "Android AAB" exports/qa-mobile-fixes/mobile.pck`. No publishing or signing is performed by this check.

The legacy water-depth render test now explicitly loads its lake fixture and identifies pooled fish by record, matching the existing distance-sorted visual pool. The gameplay and touch tests continue to load the actual river scene.

## Evidence and limits

Final run: all 19 test suites plus the import check passed. Collection passed 600 assertions and multitouch passed 251 assertions in both source and Android-pack runs. No game-script errors or failed assertions remained in that run.

Machine-readable results and individual logs: `exports/qa-mobile-fixes/final/results.json`. Exported journal screenshots: `exports/qa-mobile-fixes/packed-screenshots/` and the final runner's `screenshots/` directory. Artifacts are ignored by Git.

These are desktop executions of Android-exported resources plus injected multitouch sequences. No physical Android device was connected in ADB, so native Android touch delivery and device GPU behavior have not been verified. The existing Windows certificate-store diagnostic is unrelated to game assertions; ETC2 textures from the Android pack are converted on the desktop GPU. Original release artifacts and pending release metadata are preserved.
