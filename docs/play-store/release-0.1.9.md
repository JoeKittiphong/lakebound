# Lakebound 0.1.9 — Optimized update

Exported from latest source 23 October 2026; submitted around midnight Bangkok, 24 October.

- Package com.zylaah.lakebound; version code 10
- AAB exports/android/lakebound-0.1.9-closed.aab: 60,592,759 bytes (60.59 MB / 57.79 MiB).
- Previous AAB: 66,878,687 bytes. Reduction 6,285,928 bytes, 9.40%.
- Google Play new-install download estimate: 34.5 MB, 6.29 MB below prior release. This differs from the AAB archive and installed size.
- SHA256 ae785441962cda6e3540a53654cbbf1d956e3651e2155277a61589885bdce087
- Original upload certificate SHA256 confirmed: 22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7
- Target API 36/min 28, VIBRATE only, 16KB ARM64 ELF alignment and ZIP/secret exclusion passed. Google Play accepted bundle 10, no blocking errors; optional mapping/native symbol warnings remain.

Replaced old phone screenshots with two actual 1280x720 renders: 0.1.9-river.png and 0.1.9-character.png. Existing icon/feature artwork preserved. No AI image-generation label was added to the actual gameplay renders. User requested new illustrations during upload.

Verification: fresh headless suite logs in workspace exports/qa-0.1.9. Three old test fixtures attempted casting before the new traversal grounding requirement was met; amended fixtures to await 25 physics frames, and playtest_feedback, expansion_flow and refactor_boundaries reruns exited 0. Playtest rendered screenshots with zero failures. Existing startup teardown emits two is_inside_tree transform errors, despite all startup assertions passing and exit 0; this was not changed and is not claimed as a clean suite. No physical Android test.

Submitted Alpha release 9 and Thai store screenshot changes together. Managed publishing remains enabled; approval is separate from publication. Proof: exports/play-store/0.1.9-submitted.png.
