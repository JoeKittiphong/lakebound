# Lakebound 0.1.26 — Equipment Removal

1 November2026. Submitted and verified: Alpha release25 plus Thai phone screenshot listing changes are in review (quick checks running). Six Early Access changes remain unsubmitted. Managed publishing is on; approval still needs publishing. Proof: exports/play-store/0.1.26-submitted.png. Code27;0.1.25/code26 was cancelled before submission at user's request. Previous0.1.24 published1 November08:40.

User explicitly requested plan, implement, verify/fix, then update with new screenshots. Implementation plan: ../equipment-removal-plan.md.

Different owned rod selection atomically detaches reel,line,bait and terminal rig instead of requiring/auto-selecting a compatible owned reel. Same rod selection preserves its setup. Individual removal is available through authored per-slot controls and selected-component action in the assembled overview. Empty slots are persisted and shown; incomplete tackle cannot cast. Removing a box containing fish is refused. Inventory items remain owned; detached spools preserve exact remaining lengths in stored_lines. Legacy profiles migrate without equipment resets. Save failure restores the complete transaction. World/first-person/overview visuals remove real rod/reel/line/fill/leader meshes appropriately.

Authored UI: features/economy/showroom/shop_showroom.tscn, inline_equipment_details.tscn, loadout_view.tscn. Details, component rows and empty instructions stay editor editable. Gameplay/profile/UI null handling updated; no renderer/ABI, reset generation, countries/testers or commerce behavior changes.

Original-key AAB exports/android/lakebound-0.1.26-closed.aab:85,303,365 bytes (85.30 decimal MB),+4,070,356 bytes versus published0.1.24 (81,233,009). SHA256019cbf93291ca78247cfb5c55e3989a580b4ab9bcbaaf3e030037636917bbb8a. Same original public upload certificate22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7.

Exact archive verifier passes package/code27/version/API36/min28, INTERNET+VIBRATE only, ZIP integrity, secret/test/docs exclusions, four line materials/remap targets and ARM64 16KB alignment. Build successful,3254 assetPackInstallTime files extracted for GPU QA.

Source tests: removal58, equipment flow298, assembled loadout152, economy40, tutorial11, responsive visual78, bait visual40 assertions (677 total), all pass. Old fixtures now explicitly mount attachments after rod selection rather than relying on removed auto-equipping behavior. Tests exercise no owned matching reel, cross-family and fixed-line switching, individual removal, partial spool reuse, legacy/empty saved loadouts, pending recovery, occupied box, save rollback, real gameplay and responsive1280x720/1024x768/2400x1080 layouts. Visual review caught a leader refresh that re-showed a detached line; corrected and covered with regression assertion.

Exact AAB: removal58, responsive/visual78, starter compatibility1, six-map navigation26 checks (163 total), all pass. Logs exports/qa-0.1.26/. No script/game errors; host certificate-store and desktop ETC2 conversion diagnostics remain; removal harness reports4 ObjectDB instances at shutdown (source harness1). No physical Android/live server test in this task.

Five fresh1280x720 store screenshots in exports/play-store/0.1.26-screenshots: overview/remove controls, switched rod with empty attachments, compatible reel selection, reassembled kit (all four rendered from exact AAB), and same-source newly rendered bait-interest gameplay. Visually inspected. Replacing previous pending screenshot set; existing generated icon/feature graphic and AI labels retained. The final listing replacement was saved and submitted with Alpha.

<th>
เปลี่ยนคันเบ็ดใหม่แล้วถอดรอก สาย และเหยื่อเดิมไว้ในกระเป๋า
เพิ่มปุ่มถอดอุปกรณ์แต่ละช่องในหน้าภาพรวมชุดที่ใช้
เก็บความยาวสายที่ถอดไว้ และแสดงช่องว่างเมื่อชุดยังไม่ครบ
ปรับการแสดงผลอุปกรณ์และข้อความแนะนำ
</th>
Play accepted27/0.1.26. Review new-install estimate58.1 MB (+3.89 MB versus previous), optional mapping/native-symbol warnings only. Five final screenshots saved successfully with listing text/icon/feature graphic unchanged. Update download estimate4.76 MB. Final Console confirms both Alpha0.1.26 and Thai phone screenshot changes in review; no unrelated changes submitted.
