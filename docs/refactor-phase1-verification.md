# Refactor phase 0–1: baseline และขอบเขต Session/HUD

25 ตุลาคม 2026 · เริ่มจาก commit `961d5c2` (0.1.12)

## สิ่งที่เปลี่ยน

`gameplay.gd` เรียกความสามารถของ HUD แทน `hud.get_node(...)` ทั้งหมด:

- `configure_session(region_id, depth_limit)` กำหนดบริบทแผนที่ให้ HUD และแผงลูก
- `bind_economy(...)` ผูกแผงอุปกรณ์และภารกิจ โดย session ไม่รู้ path ภายใน
- `is_tutorial_active()`, `is_lure_action_held()` สอบถาม state ที่ session ต้องใช้
- `update_wallet(...)`, `set_boss_notice(...)`, `set_boss_notice_visible(...)`
- `open_tackle()` และ `close_top_panel()` รับคำสั่งเปิด/ปิดผ่าน owner ของแผง

HUD รวม opened/closed ของ Collection/Tackle/Missions แล้วส่งสัญญาณเมื่อ
**แผงแรกเปิด** หรือ **แผงสุดท้ายปิด** เท่านั้น คงชื่อ signal
`collection_visibility_changed` เดิมเพื่อ compatibility แต่ความหมายครอบคลุมทั้งสามแผง
session ยังเป็นเจ้าของ pause/navigation และเก็บ pause เดิมเพียงครั้งเดียว
Back คงลำดับ missions → tackle → collection โดยปิดครั้งละหนึ่งแผง

เมื่อแผงแรกเปิด HUD ล้าง joystick/aim ownership และซ่อน tutorial/settings ภายใน
ป้องกัน gesture เดิมไหลไปสู่การเหวี่ยงเบ็ดหลังปิดแผง แผงอุปกรณ์และภารกิจยกเลิก
subscription กับ service ถาวรเมื่อออกจาก tree; session ยกเลิก profile refresh
ก่อนบันทึกประชากรตอนออก เพื่อไม่ refresh โหนดที่ถูก detach แล้ว

ไม่มีการย้าย/สร้าง visual hierarchy ใหม่ ไม่มีการเปลี่ยน species IDs, region IDs,
save schema/path/reset generation, balancing, FightSimulation หรือกฎรับแรงของเอ็น
ฉากเดิมยังแก้ผ่าน Editor ได้ตามเดิม การแยก ProfileStore/CatchSettlement ยังไม่เริ่ม

## Test runner

- ลงทะเบียน script ครบ: headless 28, slow/headless 1, render 22, content 9,
  packed-only 2 (`--list` ตรวจไฟล์ตกหล่นและรายการที่ชี้ไฟล์หาย)
- `--tests` เลือกชุดตรวจเฉพาะงาน; `--rendering-method` เลือก GPU backend ของ QA
- Windows แยก APPDATA/LOCALAPPDATA และ `user://` ของแต่ละ process
- timeout หยุด process tree ของ Godot console wrapper บน Windows ก่อนเก็บผล
- River integration แยกเป็น slow เพราะเดินทั้งแม่น้ำด้วยความเร็ว production;
  ใช้ `--suite slow --timeout 600` เมื่อจะตรวจเต็ม ไม่ลดเส้นทาง/เพิ่มความเร็วให้เทสต์ผ่าน
- เพิ่ม result marker ที่ขาดใน playtest_feedback และ render smoke บางชุด
  โดยยังตรวจ error, assertion, exit code และ timeout ตามเดิม

## Baseline และการซ่อม fixture

รัน baseline ก่อนแก้ runtime และเก็บ logs ใน `exports/qa-refactor-phase1/baseline*`:

| ปัญหาที่พบก่อน refactor | สาเหตุ/การจัดการ |
|---|---|
| playtest_feedback exit 0 แต่ runner ให้ FAIL | ไม่มี result marker; เพิ่มบรรทัดสรุปจำนวน failures |
| startup_flow คาด gameplay.tscn | เมนูเปิด region scene ที่ inherit Gameplay แล้ว; ตรวจ exact selected scene/map ID และรอ asynchronous transition แทน |
| fishing_visual กล้อง 2 assertions ไม่ผ่าน | fresh profile เปิด tutorial ทับจุด gesture; fixture free-play ซ่อน tutorial และกด aim ให้ตรงสัญญา facing ปัจจุบัน บทสอนยังตรวจใน suite ของตนเอง |
| expansion_visual cast/lure 3 assertions ไม่ผ่าน | เปิด modal จน pause ก่อน player แตะพื้น; fixture รอ 30 physics frames ก่อนเปิดแผงแรก |

สอง visual failures ทำซ้ำจากสำเนาซอร์สก่อน refactor ได้เหมือนกัน และตรวจแล้วว่า
ไฟล์ gameplay/HUD/panels กับ test scripts ในสำเนาตรง commit `961d5c2` จึงแก้
precondition ของ fixture โดยคง assertions ของการหมุนกล้อง การ cast และความลึกเหยื่อ
ไม่แก้ runtime เพื่อเอาใจ fixture เก่า

## ผลหลังแก้

Godot 4.7.2 บน Windows; GPU checks ใช้ OpenGL compatibility ของเครื่อง QA
ไม่เปลี่ยน renderer ใน `project.godot`

| กลุ่ม | ผล |
|---|---|
| HUD session ใหม่ | 23 checks, 0 failures: region/depth binding, wallet/boss API, modal ซ้อน, Back, pause เดิม, สองนิ้วจริงผ่าน input events, release หลังปิดแผงไม่ cast ซ้ำ, lure button จริง และ cleanup |
| ขอบเขตเดิม/อุปกรณ์/ภารกิจ/การตกปลา | focused run ผ่าน refactor_boundaries, expansion_flow, missions, fishing_recovery |
| Headless รอบกว้างก่อนซ่อม fixture startup | 26/29 suites ผ่าน; startup ผ่านในการ rerun หลังแก้ fixture; 2 ข้อจำกัดเดิมอยู่ด้านล่าง |
| Render รอบกว้าง | 7/9 ผ่านครั้งแรก; fishing_visual/expansion_visual ผ่านหลังแก้ preconditions ที่ทำซ้ำได้จาก baseline |
| แผนที่/ปลา | regions_integration (ครบ 6 map), fish_encyclopedia, regions_fishing และ regions_legacy_save ผ่าน |
| อินพุต/แผง | mobile_multitouch 261 checks, mobile_collection, collection, missions_visual และ fishing_recovery_visual ผ่าน |
| Final fixture rerun | startup_flow, hud_session, playtest_feedback ผ่าน |

นับชื่อ source suite ไม่ซ้ำ ตรวจ 37 suites: ผลสุดท้ายผ่าน 35; 2 baseline checks
ยังไม่จบ/ไม่ผ่าน ไม่ได้อ้างว่าทั้ง repository มีผลเขียวทั้งหมด

### ข้อจำกัดที่คงไว้

- `mobile_fishing_tuning`: camera-clearance assertion เดิม `camera.y - rig.y > 2`
  ไม่ผ่านทั้งก่อนและหลัง; camera config ไม่ได้เปลี่ยนในงานนี้ และไม่ลด threshold
  เพื่อทำให้ suite เขียว
- `river_integration`: full walking loop เกิน timeout ทั้ง baseline 120 วินาทีและ
  after 180 วินาที ไม่มีผลยืนยันทั้งเส้นทางในงานนี้ จัดเป็น slow suite และเก็บ
  timeout เป็น FAIL จริง แยกจาก regions_integration/wooden_jetty ที่ผ่านแล้ว
- Windows root certificate-store diagnostic คงอยู่ แยกไว้ใน host diagnostics;
  มี ObjectDB teardown warnings ในบางชุดเดิม ตรวจ script/runtime errors แยกกัน
- ยังไม่ตรวจ Android hardware, safe area/back จริง หรือสร้าง signed bundle ใหม่

ผลเครื่องอ่านและ logs อยู่ใน `exports/qa-refactor-phase1/`:
`after-headless`, `after-render`, `focused-rerun`, `final-fixtures`,
`visual-fixtures-rerun`, `final-touch` ภาพ missions/shop/collection หลายขนาดจอถูก render และ
ตรวจด้วยตาแล้ว โฟลเดอร์หลักฐานเหล่านี้ถูก ignore ตาม repository policy

## ลำดับถัดไป

เริ่ม phase 2 ด้วย ProfileStore ที่คง façade ของ AnglerSave และ schema เดิมก่อน
แล้วจึงแยก CatchSettlement พร้อมเทสต์ duplicate delivery, failed write/retry,
quit/reopen และ reconciliation ข้าม profile/collection ห้ามถือว่าการเขียนสองไฟล์
เป็น transaction เดียวโดยอัตโนมัติ
