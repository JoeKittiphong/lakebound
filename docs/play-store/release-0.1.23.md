# Lakebound 0.1.23 — Map Loading

1 November 2026: original-key version code 24 accepted as closed Alpha release 23 and submitted. Console confirms only Alpha 0.1.23 in review (quick checks running). Six Early Access changes remain unsubmitted. Managed publishing is on: approval still requires publishing. Proof: exports/play-store/0.1.23-submitted.png.

## Change and limitation

User reports latest Android release exits to launcher when selecting maps, apparently all maps. No Android device or crash log is available, so the exact native crash cause remains unconfirmed.

Removed the unused eagerly loaded Gameplay PackedScene from the menu. An authored lightweight map_transition.tscn frees the entire previous cinematic/menu before loading the selected map on the main thread. Resource-load failure offers Retry and Back. Deferred cinematic waiting cues ignore calls after removal from the tree. Player saves and reset generation are unchanged.

Build investigation also confirmed filesystem_cache10 retained an obsolete features/menu/main_menu.tscn dependency list (including removed menu_lake.png). Backed it up to exports/filesystem_cache10-before-map-fix.bak and moved .godot/exported to .godot/exported-before-map-fix, then rebuilt with fresh caches. This cache inconsistency is not proof of the phone crash cause. Build tools use recovery mode; verbose signing diagnostics redact the password before emission. The final build has no former missing-image error and reports successful Gradle builds and completed export.

## Artifact

- AAB: exports/android/lakebound-0.1.23-closed.aab
- Size: 80,071,648 bytes (80.07 decimal MB), 4,635,742 bytes smaller than 0.1.22 (84,707,390 bytes).
- SHA256: 56d3a33028580777caba8c3581cebe4104dd766af1e09b0bb5a712d1cd77c85c
- Upload certificate SHA256: 22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7
- Play new-install download estimate: 53 MB (-4.57 MB versus previous). Update download and installed size not displayed in review.
- Play device support unchanged. Optional mapping/native-symbol warnings only.

## Validation

Exact-AAB verifier passed package/version24/API36/min28, INTERNET+VIBRATE only, ZIP integrity, signing/test/docs exclusions, and ARM64 16KB load segment alignment. Same-build XML manifest supplied; keytool confirms the original public upload certificate.

Source renderer regression: all six menu-to-map routes, old-cinematic release before map load, map save identity, failed route retry/back (26 assertions); startup intro/menu/map/back; existing carousel test all passed. Experimental threaded transition was discarded after its timeout; the final route uses main-thread loading after cleanup.

Extracted 2,616 files from this AAB's assetPackInstallTime/assets. Exact packed six-map transition test passed 26 assertions; packed startup passed; packed error screen rendered and visually inspected. Logs: exports/qa-map-transition/packed-six-maps.log, packed-startup.log, packed-visual.log. UI: exports/qa-map-transition/packed-transition-error.png. Host certificate-store diagnostic and desktop ETC2 conversion warnings remain; startup reports 7 ObjectDB instances at shutdown. No physical Android/device-crash or live-endpoint test. Successful desktop tests do not establish that the reported phone crash is fixed.

## Thai release notes

<th>
ปรับการโหลดแผนที่เพื่อลดการใช้หน่วยความจำขณะเข้าเล่น
เพิ่มหน้ารอโหลดแหล่งน้ำ พร้อมปุ่มลองใหม่เมื่อโหลดไม่สำเร็จ
ปรับการเปลี่ยนจากหน้าเมนูเข้าสู่เกม
</th>