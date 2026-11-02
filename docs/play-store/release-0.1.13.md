# Lakebound 0.1.13 — Catch saving

Prepared 25 October 2026 from the owner's latest source.

- Package com.zylaah.lakebound; version code 14.
- AAB exports/android/lakebound-0.1.13-closed.aab
- Archive 94,531,665 bytes (94.53 MB), +19,890 bytes versus 0.1.12.
- SHA256 3d1bb62bbb17af241f830534c13718986425b73943ce6f512ff49e5fe7971ef9
- Original upload certificate verified: 22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7
- Same-build manifest, ZIP, excluded secret files and ARM64 16KB alignment passed. API 36/min 28; VIBRATE only.

Source changes include durable catch journal/reconciliation across profile and collection, save-error handling and mission/status presentation. No save-reset generation change made for this release.

Existing tests: catch settlement 36, missions 76, economy 40 checks; all zero failures and exit 0. Sandbox runs logged the known Windows root certificate-store diagnostic. Exact AAB assets were extracted to exports/qa-installed-0.1.13 and ran through loading -> menu -> grand river, exit 0, using isolated QA data. Nine ObjectDB leaks remain on startup-test shutdown. No physical Android test.

Prior Alpha 0.1.12 observed available to testers, published 25 October 19:45. Alpha release 13 accepted bundle 14 (0.1.13), with only optional mapping/native symbol warnings and no blocking errors. Play new-install download estimate 68 MB (+17.3 KB). Submitted the single intended Alpha release change; publishing overview confirms Changes in review, quick checks running. Managed publishing remains enabled; not yet published. Proof: exports/play-store/0.1.13-submitted.png.

