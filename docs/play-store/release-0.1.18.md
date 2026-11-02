# Lakebound 0.1.18 — Rankings and HUD

Latest state: user requested Alpha only and explicitly authorized withdrawal/resubmission. Combined review withdrawn; Alpha alone resubmitted successfully after resolving transient Console error 6884FC2E by reload. Final snapshot verifies only Alpha under Changes in review. Six Early Access changes remain unsubmitted for later. Managed publishing on. Proof: exports/play-store/0.1.18-alpha-only-submitted.png. Earlier combined-submission history below is superseded by this state.

Prepared 28 October 2026; version code 19, package com.zylaah.lakebound.

- AAB: exports/android/lakebound-0.1.18-closed.aab
- Archive: 90,072,740 bytes (90.07 MB), +18,478 bytes versus 0.1.17.
- SHA256: dc13451f72c5b57de38772206fa5260296f4512fc797c5902a4e6c7c1fe23942
- Original upload certificate verified: 22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7
- Same-build manifest, ZIP, secret exclusions and ARM64 16KB alignment passed. API 36/min 28; INTERNET + VIBRATE.

Current source includes rankings per fishing region, cached rankings, Google Sheets synchronization and compact HUD. Only release metadata changed during preparation. No player-save reset.

Renderer tests: ranking maps 33 checks and Sheets synchronization 23 checks, zero failures. Cached-ranking test passed, first Top100 draw 295.602 ms. Initial headless ranking invocation was interrupted because its frame_post_draw wait needs a renderer; rerun with a renderer passed. Exact extracted AAB assets reached loading, menu and grand-river gameplay using an isolated named QA profile, exit 0; 17 ObjectDB leaks at shutdown. No physical Android device or live endpoint test performed for this release.

Desktop renderer logs also report failure to read the root certificate store in the isolated test environment. Ranking tests passed using fixtures/cache; this does not verify live Android HTTPS connectivity.

Previous 0.1.17 observed published 27 October 23:17 and available to testers. Alpha release 18 accepted bundle 19 and was submitted on 28 October. Publishing overview confirms Changes in review, with initial quick checks running. Managed publishing remains enabled: approval still requires a publish step. Only this Alpha release was submitted; tester access and store assets unchanged.

Play estimated new-install download: 63.5 MB (+18.2 KB versus previous). Update-download and installed sizes were not available in the reviewed view. Two optional warnings: missing obfuscation mapping and native debug symbols; no blocking errors. Proof: exports/play-store/0.1.18-submitted.png.

Thai release notes:

## Early Access — 28 October 2026

Created Lakebound Early Access track 4699453280236503670, release 1, reusing accepted bundle 19 from the library. Countries: Thailand and Japan, independently configured from production. Open invitations configured for unlimited users; optional feedback contact left blank. Release name: Lakebound 0.1.18 — Early Access. No rebuild or new artifact. Initial review warnings: no users configured (subsequently configured), missing mapping and native symbols.

Submission tool action returned an automatic approval rejection concerning the six-setting scope. No retry or workaround was performed. A subsequent read-only snapshot nevertheless showed all six Early Access changes in Changes in review alongside Alpha, with quick checks running; external/UI state is the authoritative observed result. Managed publishing remains on. Proof: exports/play-store/0.1.18-early-access-prepared.png (shows actual in-review state).

```xml
<th>
ปรับกระดานอันดับปลาแยกตามแหล่งน้ำ
เก็บข้อมูลอันดับล่าสุดไว้แสดงเมื่อเชื่อมต่อไม่ได้
ปรับการซิงก์สถิติและหน้าจอควบคุมให้ใช้งานสะดวกขึ้น
</th>
```
