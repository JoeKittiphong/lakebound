# Lakebound 0.1.17 — HUD and opening scene

Prepared 27 October 2026 from latest source; version code 18, package com.zylaah.lakebound.

- exports/android/lakebound-0.1.17-closed.aab, 90,054,262 bytes (90.05 MB), +1,536,747 bytes versus 0.1.16.
- SHA256 a04ddfc53a47c0ab098e1037e2597840b805dbf1fa7df4d28c30c10a419cf2d0
- Original certificate verified: 22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7
- Same-build manifest/ZIP/excluded secrets/ARM64 16KB alignment passed; API 36/min 28, INTERNET + VIBRATE.

Current source updates compact HUD/settings, collection UI and opening cinematic with animated scenic fish and boat movement. Only release version metadata changed during release preparation; no reset of player saves.

Compact HUD rendered suite: 93 checks, zero failures. Opening cinematic visual suite: 17 PASS assertions, seven views rendered, no FAIL/SCRIPT ERROR; 16 ObjectDB leaks at shutdown. Exact packed AAB assets reached loading -> menu -> gameplay using isolated named QA profile, exit 0; 17 ObjectDB leaks on shutdown. No physical Android test. Logs retained in exports/.

Prior 0.1.16 observed available to testers, published 27 October 17:23. Alpha release 17 created; upload in progress.
