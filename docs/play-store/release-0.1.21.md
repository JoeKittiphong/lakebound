# Lakebound 0.1.21 — Loading and Minimap

Prepared 31 October 2026; package com.zylaah.lakebound, version code22. Alpha only; keep Early Access six changes deferred. Prior 0.1.20 observed available to some testers, published29 October21:13.

Current source updates opening rainforest, minimap/local view and region selection. Existing build preflight now checks texture budgets, imports, dependency reachability and selected-resource exports (1,564 resources). Only version metadata changed during release preparation; no save reset, renderer or architecture changes.

Artifact exports/android/lakebound-0.1.21-closed.aab:84,307,021 bytes (84.31 MB),9,212,133 bytes smaller than0.1.20 (-9.85%). SHA256 e25ef0665b0491b7910c2713098cbb89f0b381a22760605ab36f3cfd0258e477. Same-build manifest, ZIP, secret exclusions and ARM64 16KB checks passed; API36/min28, INTERNET+VIBRATE. Original upload certificate verified:22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7.

Source QA passed: loading jungle (779 instances,206 trees,63 authored batches), minimap scan38 checks, collection navigation/persistence. Loading rendered1280x720,1600x720,1024x768;1280 image visually inspected. Exact extracted install-time AAB assets passed packed_cleanup1595 checks: all selected resources present, six map rosters/HUD and carousel pictures load.15 ObjectDB leaks on packed-cleanup shutdown;13 on visual test. Host certificate-store diagnostic remains. No physical Android/live endpoint test.

Exact AAB startup also reached menu and gameplay, with no script errors;15 ObjectDB leaks at shutdown. Alpha release21 accepted bundle22 and submitted31 October. Final Console confirms Alpha0.1.21 alone under Changes in review, initial quick checks running. Early Access six changes remain unsubmitted. Managed publishing on; approval still requires publication. Two initial submission attempts did not persist; after reloading Console and reselecting Alpha only, submission succeeded. Proof:exports/play-store/0.1.21-submitted.png.

Play new-install download estimate57.2 MB (-9.6 MB versus0.1.20). Update-download estimate9.21 MB appeared on review page; installed size not observed. Two optional warnings:missing mapping and native debug symbols. No blocking errors or device-support removals. Store images and tester access unchanged.

```xml
<th>
ปรับฉากเปิดเกมและบรรยากาศป่าริมน้ำ
ปรับมินิแมปและการแสดงตำแหน่งรอบตัวผู้เล่น
ปรับหน้าจอเลือกแหล่งน้ำและลดไฟล์ที่ไม่จำเป็นในตัวเกม
</th>
```
