# Lakebound 0.1.10 — Loading fix

Prepared 24 October 2026 from the owner's latest fixed source, after a mobile loading failure report.

- Version code 11; package com.zylaah.lakebound
- AAB exports/android/lakebound-0.1.10-closed.aab
- Size 61,284,768 bytes (61.28 MB)
- SHA256 29f835574e2af7cabf1ea64df3f77a3201d059740d80d81677904a72afa6f9e1
- Original upload certificate verified: 22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7
- API 36/min 28, VIBRATE only; ZIP integrity, secret exclusion and ARM64 16KB ELF alignment passed.

The earlier exact 0.1.9 asset extraction logged a missing res://assets/ui/modern/eye.svg plus an invalid UID reference. Current HUD source has the path-only reference. This is evidence of an old packed dependency issue, not definitive device log proof of the reported failure.

Extracted the install-time game assets from the exact new AAB to exports/qa-installed-0.1.10 and ran exports/verify_packed_startup.gd against those files with an isolated APPDATA QA profile. Real-time run (max-fps 60) exited 0, reached menu via the loading scene and then reached gameplay, with no resource/parse errors. Log: exports/qa-installed-0.1.10-realtime.log. Eleven ObjectDB leaks at shutdown remain. An initial fixed-fps run hit the test's frame timeout while threaded loading was still working and emitted parse errors during teardown; real-time rerun avoids that test timing artifact. No physical Android device test was available.

Alpha release 10 created. Prior 0.1.9 was observed available to testers, published 24 October 04:17. Google Play accepted bundle 11 with no blocking validation errors; optional mapping/native symbol warnings remain. Estimated new-install download 35.2 MB. Submitted the single Alpha release change for review. Managed publishing remains enabled. Proof: exports/play-store/0.1.10-submitted.png.
