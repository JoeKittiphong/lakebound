# Lakebound 0.1.22 — Fish Health and Fight

Prepared31 October2026; package com.zylaah.lakebound, code23. Alpha only. Prior0.1.21 observed available to some testers, published31 October15:06. Six Early Access changes remain deferred.

Latest source adds fish health bar, adjusts fight/line strength tuning and first-catch tutorial/HUD guidance. Release preparation changes only project, AAB preset and menu version metadata; no save reset.

Exact artifact:exports/android/lakebound-0.1.22-closed.aab,84,707,390 bytes(84.71 MB),+400,369 bytes versus0.1.21. SHA256980fc8689e4e9e8f052b076646d49baa53fbcef4f0c0567cb959f3473a2eea90. Same-build manifest/ZIP/secret exclusions/ARM64 16KB checks passed;API36/min28,INTERNET+VIBRATE. Original upload certificate verified:22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7.

QA source suites passed:fish_health60,fishing_recovery64,fishing_simulation60 checks,184 total,zero failures. Exact AAB packed_cleanup passed1632 checks with renderer and no script errors; desktop converts ETC2 textures to supported formats,8 ObjectDB leaks on shutdown. Initial headless packed cleanup hit DummyMesh renderer diagnostic; renderer rerun passed. Exact AAB startup reached menu/gameplay;14 shutdown ObjectDB leaks. Host certificate-store diagnostic remains. No physical Android/live endpoint test.

Build logged inability to read obsolete features/menu/art/menu_lake.png. File is absent, and no current scene/script/export reachability reference was found (only historical prototype notes). Current menu and all selected resources load in exact-artifact tests; diagnostic retained rather than represented as a clean build log.

Alpha draft release22 created; upload in progress, not submitted yet.

```xml
<th>
เพิ่มแถบพลังปลาและปรับการแสดงผลระหว่างสู้ปลา
ปรับสมดุลแรงปลาและความทนทานของสายตามอุปกรณ์
ปรับคำแนะนำในบทสอนตกปลาและหน้าจอควบคุม
</th>
```
