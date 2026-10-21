# Tester progress reset — 21 October 2026

The owner requested all testers start again. Collection and tutorial now use the fixed PlayerSavePaths reset generation 20261021. Existing collection statistics and tutorial completion are not loaded. Fresh progress is saved normally and survives reopening and subsequent app updates. Do not increment this generation with every release.

Legacy files are retained locally but ignored, so no irreversible file deletion or startup deletion loop is needed. Only collection and tutorial files were found in current game source. This is a bundled client change; installed copies will only reset after installing a future AAB containing it. Previously uploaded 0.1.6 is unchanged.
