# Cleanup, export structure and build size — 31 October 2026

## Result

All six maps, fish species, equipment, saved-player formats, editor-editable scenes and the Godot 4.7.2 Mobile renderer are retained. Numbers below are decimal MB, measured from builds of the working project immediately before and after this cleanup. No store upload was performed.

| Measurement | Before | Verified after |
|---|---:|---:|
| Android AAB, ARM32 + ARM64 | 92.30 MB | 84.31 MB |
| Compressed game assets within AAB | 37.81 MB | 29.96 MB |
| bundletool download estimate, same ARM64 device | 64.97 MB | 57.14 MB |
| Sum of uncompressed device APK contents | 162.63 MB | 150.71 MB |
| Standalone compact ARM64 QA APK | — | 61.33 MB |

AAB reduction: 7,993,976 bytes (8.66%). Estimated ARM64 download reduction: 7,828,670 bytes (12.05%). The uncompressed payload is not a measurement of Android Settings storage, app saves or cache. Device specification: ARM64, SDK35, density420, locale en. No phone was connected.

Final artifacts are `exports/cleanup-qa/verified/lakebound-clean-qa.aab` and `lakebound-clean-arm64-qa.apk`. They use the existing separate QA signing identity and cannot update an installed production-signed app. The production signing identity, release version and publishing state were not changed.

## Structure and ownership

| Location | Contents |
|---|---|
| `features/` | Gameplay and feature UI scenes/scripts |
| `actors/`, `world/` | Reusable actors and authored environment scenes |
| `data/`, `shared/`, `assets/` | Runtime catalogs, shared components and imported runtime art |
| `tools/` | Offline authoring, export preflight, texture budgets and build verification |
| `tests/` | Source and packed-runtime regression suites; excluded from release |
| `docs/` | Architecture, reports and archive index; excluded from release |
| `exports/` | Ignored builds, measurements, screenshots and diagnostics |
| Workspace `assets-source/project_archive/cleanup-2026-10-31/` | Archived historical source GLBs/art and duplicate textures, outside the Godot project |

The feature-first runtime hierarchy was already established; moving every live scene for cosmetic folder changes would add path risk without reducing builds. This cleanup instead separates authoring sources and diagnostics from runtime, consolidates shared textures, and makes the build boundary explicit.

20 files totaling 33,913,412 source bytes were archived with SHA-256 identities. Nothing from the existing vegetation/rock authoring library was deleted. Seven historical, runtime-unreferenced source/art files and their import metadata moved out; three duplicate rock texture pairs now share canonical, byte-identical textures. The five rock mesh resources have their external paths/UID references corrected. Root-level old logs moved to `exports/diagnostics/legacy-root/`.

See `cleanup-source-archive.json`. `python tools/restore_archived_source.py` lists missing archived files; add `--restore` to restore them without overwriting current files. Restore historical sources before running an old authoring generator that expects their old paths. The archive is local workspace content; preserve it separately when moving machines. Runtime builds do not need it.

## Export refactor

- Replace `all_resources` with an explicit dependency-selected resource list in every preset. Runtime global-class scripts, data catalogs and dynamically selected maps are retained as roots. Raw map/encyclopedia JSON and the font license have explicit include filters.
- The audit uses Godot's resource recognition/dependency API rather than a hand-written extension whitelist. An early packed test caught the bitmap symbol font omitted by an extension whitelist; the final AAB/APK and isolated smoke test include and load it.
- Exclude tools/tests/docs/exports, private backend/signing folders, editor templates, logs and nested project output.
- Remove the obsolete example-package Android preset. Retain named AAB, universal playtest APK, compact ARM64 APK and Web presets. Android run mapping points to the real AAB preset. APK package version now matches the existing 0.1.20/code21 AAB.
- `prepare_export.ps1` validates texture budgets, imports, obtains fresh dependencies and regenerates the selected-resource manifest. `build_release.ps1` invokes it before accessing production signing material. The production signing step was not invoked in this task.
- QA builds accept `--preset` and use per-artifact logs/results, preventing AAB/APK results from overwriting each other.

Rebuild manifest after authoring new maps or dynamically loaded resources:

```powershell
./tools/prepare_export.ps1 -Godot <Godot-4.7.2-executable> -Python <Python-executable>
```

The output dependency audit and graph live under ignored `exports/cleanup-qa/`; they are generated, not prerequisites checked into source. `tools/optimize_export.py` checks whether the serialized preset manifest matches the latest audit; `--apply` updates it.

## Import budgets

Original PNG pixels remain untouched. The shared rock normal imports at512 and roughness at256. The distant forest background imports at1024. Six selector maps import at1024 with lossy quality0.9; the game displays these at about480x270. Budgets are recorded in `tools/texture_budget.json`; `apply_texture_budget.py --check` validates all72 texture/atlas settings. Existing nearby albedo, character geometry, fish models and other map geometry retain their previous quality.

Both native AAB ABIs and all native-library SHA-256 identities match the baseline. Compact APK removes only the unused ARM32 ABI for users with ARM64 phones and compresses native libraries. Further large native-engine reductions would require a separately built/validated custom engine; this pass keeps the installed engine and supported AAB CPU architectures.

## Verification

- Both final Android archives build successfully in release mode with QA signing. ZIP CRCs, symbol-font presence, absence of development/private files and unchanged AAB native-library identities pass `tools/verify_cleanup_build.py`.
- Game assets extracted from the actual final AAB run from an empty directory, with no source-tree fallback: 1595 checks, zero failures. The test loads the loading rainforest, HUD, fish rosters and every map, then all six map selector images. `tests/packed_cleanup_test.gd` is external to the release pack.
- Source regression: regions integration, resident live-bait fishing in all six maps, equipment catalog, collection/save/navigation, loading flow, loading motion and loading scenery: seven suites, zero failures.
- GPU verification: map carousel, minimap scanning and 3D collection book: three suites, zero failures. Compressed selector artwork reviewed at actual size.
- Legacy fixture corrections: shore casting now aims at actual adjacent water and moves onto the current long jetty for the large map; resident live-bait tests exclude fish under docks and lure-only fish; collection assertions use catalog IDs instead of assuming every catalog is in one fixed order. Collection screenshots are skipped in headless mode. Runtime fishing and collection behavior were not weakened or rewritten.
- Packed headless exit still reports15 ObjectDB instances; no missing-resource or script errors remain. Windows headless runs may also report the existing root-certificate-store environment warning. Physical Android gameplay/FPS was not tested.

Evidence: `exports/cleanup-qa/build-comparison.json`, `device-size.json`, `regression-results.json`, `visual-results.json`, `packed-actual-aab.log` and per-suite logs. Intermediate invalid test builds are not the final artifacts.
