# Lakebound 0.1.28 / code31 — 3 November 2026

Ordinary Alpha update requested. Created Alpha release27 after observing0.1.27 available to some testers, published3 November04:00. No Early Access, production, tester or country changes requested.

Changes from current source: in-game owned-equipment bag with3D model previews, four fish slots with swipe pagination, in-game purchase lock with menu-only buying, actual owned loadout/stock in competition, match HUD below minimap and first/third-person camera control across fishing states. Existing account-isolated Google login and Android callback build fix retained. Cloud sync remains disabled in online.cfg.

Source checks: gameplay_bag, match_hud_layout, competition_session/transport, Google auth/startup, economy, equipment removal and hud_session selected. Rendered bag and match-HUD suites pass; detailed equipment/camera329 checks pass. Viewed actual1280px bag/HUD captures; previews and responsive controls visible. Isolated profiles and online writes disabled for QA. Final code31 validations and packed checks passed after the documented corrections; submitted to review.

No backend reset or schema deployment. No physical Android or simultaneous multi-account live match test this task. Preserve existing store screenshots for this ordinary update.

<th>
เพิ่มแถบกระเป๋าอุปกรณ์ในสนาม พร้อมภาพตัวอย่างอุปกรณ์และปลาแบบ 3 มิติ
เลือกใช้อุปกรณ์ที่มีอยู่และปัดดูปลาในกระเป๋าได้สะดวกขึ้น
ปรับหน้าจออันดับแข่งขันและปุ่มสลับมุมกล้องบุคคลที่หนึ่ง/สาม
ปรับการใช้อุปกรณ์และสต็อกในการแข่งขัน ซื้ออุปกรณ์ได้จากหน้าเมนู
</th>

Build complete: both Gradle tasks successful, original upload certificate SHA25622:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7. Exact AAB85,177,491 bytes (85.177491 decimal MB), -231,328 bytes from0.1.27. SHA2569b16056377bd643095b89c06be76cf789f21ae93923e18c3c191b092da35d7ee. Package/name/code/API36/min28/INTERNET+VIBRATE, ZIP/material/remap/exclusion/16KB ARM64 and OAuth callback checks passed. Validation report exports/validation-0.1.28.json. No signing secrets printed.

Initial source runner: all selected suites except equipment_removal exited cleanly. Equipment removal reached58 assertions/0 failures then hit180s shutdown timeout; preserved failed result. Isolated rendered retry completed58/0 and exit0 (render-equipment_removal.log), so no code/test assertion weakened. Source rendered bag and match HUD33 checks pass; camera329 checks pass. Windows certificate store and one ObjectDB shutdown leak remain; export shutdown socket/StringName diagnostics after success. Extracted3317 exact AAB files for packed checks.

Pre-submission exact-AAB visual QA caught code30 BagDock at top-left over minimap and three camera/bag adjacency failures. Source preview was correct but root/instance lacked explicit layout_mode=1, so binary export lost anchored placement. Added authored layout mode in bag_dock.tscn and fishing_hud.tscn, plus safe-area bottom-position assertion at1280/1024/1600. The assertion compares UI safe-area coordinates rather than physical root pixels because project content scaling changes1024 coordinate height. A binary save/reload roundtrip confirms rect(396,632,56,76), anchors1/mode1 at1280x720. Initial code30 stays unsubmitted library-only; corrected release uses code31. Initial packed camera harness referenced an intentionally unexported base gameplay scene and timed out after load error; final packed fixture uses shipped grand_river scene instead; initial packed bag behavior passed but layout failure was not ignored.

Final code31 artifact supersedes initial code30 values above:85,177,518 bytes (85.177518 MB),231,301 bytes smaller than0.1.27. SHA256a1eaf667fd5890084380a24fc1aa7ebe979a7b1ea8ac437a8228de67eb3352c9. Final manifest/certificate/archive/material/16KB checks pass. Final packed gameplay_bag exits0/0 failures; match_hud_layout36/0 across3 widths; detailed equipment/camera329/0 on actual shipped grand_river scene. Viewed final packed1280 bag capture, now bottom-aligned and clear of minimap. Harness-only original camera scene path replaced with shipped scene, isolated save path used. Final packed runner exits0. Desktop ETC2 conversion and host certificate diagnostics remain.

Final Console state: original-key31(0.1.28) is the only new bundle in Alpha release27, previous29 excluded,30 not submitted. Play new-install57.9 MB (-231 KB), device support unchanged; update and installed size not displayed. Optional mapping/native-symbol warnings only. Saved and submitted1 Alpha change; Console shows Lakebound0.1.28 — Bag & Match HUD in Changes in review with quick checks running. Six Early Access changes remain unsubmitted. Managed publishing on: not yet approved/published. Proof exports/play-store/0.1.28-submitted.png. No store listing/screenshot changes in this task.
