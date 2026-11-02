# Lakebound 0.1.19 — Water and Collection

Prepared 29 October 2026, package com.zylaah.lakebound, version code 20. Alpha only; Early Access six pending changes must remain deferred.

Latest source updates surface spray and collection journal with region tabs, missing-species filter and collection progress. Release metadata updated in project, Android AAB preset and menu label; player saves not reset.

Focused source QA: surface_spray, collection and fishing_map_data passed (43 map-data checks). Additional collection_tabs rendered test passed 69 checks. Isolated test profiles used. Host root-certificate-store diagnostics recorded separately. No physical Android/live endpoint test.

First AAB startup reached gameplay but emitted repeated LeftHandIK null errors: the authored node added below the imported Asset instance was lost during export packing. Added editable Asset path in actors/player/angler_model.tscn, preserving authored hierarchy. Source instantiate/repack smoke confirms IK exists and retains root owner. Rebuilt exact AAB startup reaches menu and gameplay with no SCRIPT ERROR or missing node diagnostics; 14 ObjectDB leaks remain at exit. Character integration regression passed. Initial extraction mistakenly used base/assets (empty) instead of assetPackInstallTime/assets; corrected before final validation.

Final artifact: exports/android/lakebound-0.1.19-closed.aab, 93,482,274 bytes (93.48 MB), +3,409,534 bytes (+3.79%) versus 0.1.18. SHA256 bc46cf6725f24e3ef74bea5e9f6c33b19a5c84246d37b133e4b7df00685b3918. Same-build manifest/ZIP/exclusions/ARM64 16KB validation passed; API36/min28, INTERNET+VIBRATE. Original signing certificate confirmed: 22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7.

Alpha release 18 / 0.1.18 observed available to some testers, published 28 October 14:43. Alpha release 19, Lakebound 0.1.19 — Water and Collection, accepted bundle 20 and was submitted on 29 October. Final publishing overview confirms Alpha alone in Changes in review, initial quick checks running. Six Early Access changes remain unsubmitted for later. Managed publishing remains on; approval still requires publication. Proof: exports/play-store/0.1.19-submitted.png.

Play new-install download estimate 66.8 MB (+3.3 MB versus previous). Update-download and installed size not available in reviewed view. Two optional warnings: missing obfuscation mapping and native debug symbols, no blocking errors. No store images changed.

```xml
<th>
ปรับเอฟเฟกต์น้ำกระเซ็นระหว่างตกปลา
ปรับสมุดสะสมปลา แยกดูตามแหล่งน้ำและกรองปลาที่ยังไม่พบได้สะดวกขึ้น
ปรับการแสดงความคืบหน้าการสะสมปลา
</th>
```
