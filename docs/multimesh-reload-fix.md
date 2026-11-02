# MultiMesh reload fix — 1 November 2026

Reproduced both reported errors using ResourceLoader.CACHE_MODE_REPLACE on the cached river garden scene.
The first load succeeds; reloading a populated MultiMesh tries to reapply transform_format/use_colors before its instance allocation is cleared. The Editor also reproduced this during scene reopening.

Replaced serialized populated 3D MultiMeshes in six garden dressing scenes and the river world with the existing foliage_batch.gd CPU-authored format. Transforms, colors, mesh references, metadata, grouping and visibility distances are preserved. Each batch creates a fresh MultiMesh on entering the tree, sets its format before allocating instances and frees it on exit. The garden authoring tool now emits this format as well.
The water stamp template starts at zero instances; water_interactions.gd still allocates its fixed twelve-event GPU pool at runtime.

Verification:
- Both messages reproduced before the patch; zero occurrences in cache reload and Editor import after it.
- GPU migration audit: 46,677 checks, zero failures; all 10,735 original instances preserve count, transform and tint.
- Region integration: 1,720 checks, zero failures.
- GPU water interaction regression: zero failures.
- Authoring tool parse check passes.
- Existing region test reports two ObjectDB instances/one resource still in use on shutdown; not represented as a native Android crash trace.

Artifacts: output/multimesh-fix/reload.log (before), reload_fixed.log, editor_fixed.log, verify.log, before-data.json.
Portable regression: tests/multimesh_reload_test.gd.
One-off original-data comparison: tools/verify_multimesh_migration.gd (requires the before-data.json audit artifact).

The exact Play AAB 0.1.22 contains the rod/reel JSON data, so missing those files was ruled out by archive inspection.
No Android device is currently listed by adb. These errors are fixed in source; they alone do not prove the cause of the reported Android process exit. Collect adb logcat/tombstone from the installed app before claiming that Android crash is resolved. Existing Play installations require a newly exported release to receive this source fix.
