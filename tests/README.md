# Regression tests

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
| startup_flow | threaded loading → menu → Play → gameplay → Back |
| fishing_simulation | bait/depth, bite, fight, failures, keep/release, seeds และ frame rates |
| fish_catalog_fishing | ตกปลาได้ครบ 16 species |
| fish_models | catalog/model/animation resources |
| refactor_boundaries | pure numerical simulation, v1/future save, pause ownership, configured speed และ cast duration |
| collection | save/reload, สถิติ, touch modal, silhouette/atlas และ responsive grid |
| fishing_visual | gestures, two joysticks, camera, fight/result actions และหลาย aspect ratios |
| fish_render | model gallery, collection, ปลาใกล้ผิวน้ำ และ catch preview |
| water_render | ความลึกปลา, visual pool, ผิวน้ำและพื้นทะเลสาบ; ภาพของชุดนี้อยู่ใน `exports/qa-water/` |

`host_diagnostics` เก็บข้อความเฉพาะที่ทราบว่ามาจาก host/sandbox โดยไม่กลบ SCRIPT ERROR ข้อความใหม่ที่ไม่อยู่ในรายการจะทำให้ suite ล้มเหลวและต้องตรวจ log

Desktop tests ไม่ยืนยัน Android hardware, touch จริง, system safe area หรือ vibration และ runner ไม่ build/sign/release แอป
