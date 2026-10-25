# 0.1.9 startup failure — 24 October 2026

Reproduced from submitted bundle 10, SHA256
ae785441962cda6e3540a53654cbbf1d956e3651e2155277a61589885bdce087.
Reconstructed a desktop-readable ZIP from the AAB asset modules without changing
their resource contents. Running startup_flow_test against it fails: the exported
fishing_hud scene still references assets/ui/modern/eye.svg, but all modern SVGs
were excluded by the export presets. The missing dependency propagates through
gameplay and main_menu, causing the loading screen's retry state every time.
This is a bundled resource error, not a network download failure.

Removed the blanket modern SVG exclusion in every Android preset. Collection
art and river authoring exclusions remain. Keep runtime dependencies available
even when most UI artwork uses the atlas.

Verification:
- Original bundle assets: startup test reproduces menu-load failure.
- Same original assets plus only eye.svg.import and its imported ctex: all four
  startup/navigation assertions pass (loading → menu → gameplay → menu).
- Updated source UI atlas test: 91 checks, zero failures.
- Added an explicit runtime-icon assertion to startup_flow_test and included
  startup_flow in run_tests.py --android-pack verification.
- Existing teardown is_inside_tree transform errors and ObjectDB leak warnings
  remain; the restored old bundle also reports a UID fallback for the restored
  icon. These are not a clean overall engine log.
- Attempts to export a fresh Android resource pack stalled at savepack and were
  stopped. No newly signed AAB, physical Android test, or Play Console update was
  completed in this fix. Do not treat the diagnostic restored ZIP as a release.

Evidence: exports/startup-fix/original.log, restored-eye.log, ui-atlas.log.
Before uploading a replacement, build a signed bundle with a new version code
and run startup verification on that exact bundle's exported assets.
