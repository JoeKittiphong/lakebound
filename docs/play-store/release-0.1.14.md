# Lakebound 0.1.14 — Fishing maps

Prepared 26 October 2026 from current source; version code 15, package com.zylaah.lakebound.

- AAB exports/android/lakebound-0.1.14-closed.aab
- Archive 87,370,971 bytes (87.37 MB), 7,160,694 bytes smaller than 0.1.13.
- SHA256 9cb27f550f39c3d15b37ae3b149e4eb0ffc238ad9ad1b988c92d96fb1eaa5f75
- Original upload certificate verified: 22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7
- Same-build manifest, ZIP integrity, secret exclusion and ARM64 16KB alignment passed. API 36/min 28; VIBRATE only.

Current source adds regional fishing maps, minimap, catch-history markers, zoom/pan and collection presentation changes. Release preparation changed version metadata only; player reset generation unchanged.

Tests: map data 43, rendered map UI 68, catch settlement 36, economy 40 checks, all zero failures. Known sandbox root certificate diagnostic appeared. Exact AAB install-time assets reached loading -> menu -> grand river, exit 0 using isolated QA data. Nine ObjectDB leaks remain on shutdown. No physical Android test.

Prior Alpha 0.1.13 observed available to testers, published 25 October 23:25. Alpha release 14 accepted bundle 15 (0.1.14) with optional missing mapping/native debug symbols warnings only; no blocking errors. Play new-install estimate 60.9 MB (-7.17 MB). Submitted the single intended release change. Publishing overview confirms Changes in review with quick checks running; managed publishing enabled, not yet published. Proof: exports/play-store/0.1.14-submitted.png. Tester access left as observed (zylaah list, 19 users).

