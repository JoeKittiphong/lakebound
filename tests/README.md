# Regression tests

## เลือกชุดตรวจสำหรับ refactor

```powershell
python tools/run_tests.py --list
python tools/run_tests.py --godot <godot-console.exe> --tests hud_session refactor_boundaries startup_flow
python tools/run_tests.py --godot <godot-console.exe> --tests regions_integration mobile_multitouch missions_visual --rendering-method gl_compatibility
python tools/run_tests.py --godot <godot-console.exe> --suite slow --timeout 600
```

`--list` ตรวจด้วยว่ามี test script ตกหล่นจากทะเบียนหรือทะเบียนอ้างไฟล์ที่หายไป
`--tests` เลือกตรวจเฉพาะชื่อที่ระบุโดยใช้โหมด headless/render ของทะเบียนเดิม
`content` เป็นชุดตรวจ asset authoring ที่เลือกแยกได้; `all` รวม content และ slow
ด้วย ส่วน `packed_size`/`packed_memory_smoke` ต้องเรียกด้วย artifact จริงผ่าน
Godot `--main-pack` ไม่ใช่รันจาก source แล้วอ้างว่าผ่าน packed verification

`slow` แยก river_integration ที่เดินรอบแม่น้ำด้วยความเร็วจริงออกจากรอบเร็ว
อย่าเร่งตัวละครหรือลดเส้นทางเพื่อให้ผ่าน timeout ของรอบเร็ว ให้ตั้งเวลาตามคำสั่งข้างบน
runner ไม่ถือว่า timeout คือ pass และจะหยุด process tree ของ Godot บน Windows

บน Windows แต่ละ test process มี APPDATA/LOCALAPPDATA และ `user://` แยกใต้
`<output>/profiles/<test>/` เพื่อไม่ให้ tutorial/เซฟที่ suite ก่อนหน้าเขียนมีผลต่อ
suite ถัดไป Fixtures บางตัวเขียนไฟล์ QA ลง `res://exports/` โดยตรง จึงยังไม่ควร
รัน suite เดียวกันหลาย process ทับกันใน checkout เดียว

ขอบเขตและผลรอบล่าสุด: [refactor-phase1-verification.md](../docs/refactor-phase1-verification.md)

ต้องมี Godot console executable รุ่นเดียวกับโปรเจค และ Python 3 ตั้ง `LAKEBOUND_GODOT` หรือส่ง `--godot` ไม่มีการดาวน์โหลด engine อัตโนมัติ

```powershell
python tools/run_tests.py --godot <godot-console.exe> --suite headless
python tools/run_tests.py --godot <godot-console.exe> --suite render
python tools/run_tests.py --godot <godot-console.exe> --suite all --output exports/qa-refactor/final
```

`headless` เป็นค่าเริ่มต้น รวม startup/navigation, simulation, catalog, models และ refactor boundaries; `render` ใช้ GPU สำหรับ collection, touch/keyboard และ screenshot ห้ามรันชุด render ด้วย `--headless` เพราะรอ `frame_post_draw`

Runner import project ก่อนทดสอบ จำกัดเวลาแต่ละ process 120 วินาที (เปลี่ยนด้วย `--timeout`) และคืน nonzero เมื่อ timeout, script/runtime error, FAIL หรือไม่มี result marker ผลอ่านได้จาก `results.json`, logs และ `screenshots/` ภายใต้ output

บน Windows runner กำหนด APPDATA/LOCALAPPDATA ของ subprocess ให้อยู่ใน QA profile เพื่อแยก `user://` และ engine cache จากข้อมูลผู้เล่น ส่วน collection fixture เขียนใน QA output ผ่าน `LAKEBOUND_QA_DIR` เสมอ รันหลายชุดพร้อมกันควรใช้ output คนละ directory

| Test | สิ่งที่ตรวจ |
|---|---|
| economy | wallet/inventory save/reload, ซื้อ/เปลี่ยนสาย, กล่องปลา/ขาย, กู้คืนด้วยเพชรหรือ reward ที่ยืนยันแล้ว, callback ซ้ำ, save failure rollback, ชุดสำรอง, lure gestures และ boss population |
| expansion_flow | กระเป๋า/pause, cast → lure action → slack/break → recovery → boss catch → keep → sell → save pond |
| expansion_visual | หน้าร้าน/กู้คืน/ข้อมูลบ่อ, ปุ่มซื้อ/ยอมเสียเหยื่อ และภาพ 1280×720 / 1600×720 |
| first_catch_tutorial | ผู้เล่นใหม่, waypoint, รอ/วัด/สู้ปลา, บันทึก completion และกลับเข้าเกม |
| startup_flow | threaded loading → menu → Play → gameplay → Back |
| camera_movement | จอยและ keyboard ตามกล้อง 0°/90°/180°/−90°, แพนขณะกดเดิน และก้มกล้องโดยไม่ลดความเร็ว |
| bait_retrieval | รอกหลังเหยื่อลงน้ำ, สายหย่อน/เก็บสาย, เหยื่อเคลื่อนจริง, เก็บอัตโนมัติ และดึงรอกวัดเบ็ด |
| rod_tension | บาร์คันเบ็ดเหนือรอก, ความยาวตามน้ำหนักปลา, โซนแดงตามชนิดปลา และแรงตึงจริง |
| active_scene_movement | จอยสัมผัสและเมาส์จำลอง device −1 ในฉากเล่นจริง, ทิศเดินเทียบกล้อง, ปล่อยจอยและอินพุตสัมผัสซ้ำ |
| fishing_simulation | bait/depth, bite, fight, failures, keep/release, seeds และ frame rates |
| fish_catalog_fishing | ตกปลาได้ครบ 16 species |
| fish_models | catalog/model/animation resources |
| refactor_boundaries | pure numerical simulation, v1/future save, pause ownership, configured speed และ cast duration |
| collection | save/reload, สถิติ, touch modal, silhouette/atlas และ responsive grid |
| fishing_visual | gestures, two joysticks, camera, fight/result actions และหลาย aspect ratios |
| fish_render | model gallery, collection, ปลาใกล้ผิวน้ำ และ catch preview |
| water_render | ความลึกปลา, visual pool, ผิวน้ำและพื้นทะเลสาบ; ภาพของชุดนี้อยู่ใน `exports/qa-water/` |
| water_interactions | คลื่นจากปลาโผล่และการลุยน้ำ, ไม่เกิดวงน้ำบนสะพาน, จำกัด pool และหมดอายุ; ภาพอยู่ใน `exports/qa-water-interactions/` |
| water_optimization | วัด CPU/GPU ของ field คลื่น, ตรวจหมดอายุ/ล้างข้อมูล; ตั้ง `LAKEBOUND_WATER_REFERENCE` เพื่อเทียบข้อมูลกับ script รุ่นก่อน; ผลอยู่ใน `exports/qa-water-optimization/` |

`host_diagnostics` เก็บข้อความเฉพาะที่ทราบว่ามาจาก host/sandbox โดยไม่กลบ SCRIPT ERROR ข้อความใหม่ที่ไม่อยู่ในรายการจะทำให้ suite ล้มเหลวและต้องตรวจ log

Desktop tests ไม่ยืนยัน Android hardware, touch จริง, system safe area หรือ vibration และ runner ไม่ build/sign/release แอป

`fish_behavior_test.gd` checks all species for fresh red > green, fatigue/surge zone changes, actual green escape distance, and faster fatigue under yellow control. Fight regression bots follow the visible dynamic yellow band rather than the former fixed 72% threshold.
