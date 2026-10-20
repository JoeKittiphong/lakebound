# ผลตรวจ refactor — 20 ตุลาคม 2026

ตรวจด้วย Godot 4.7.2 บน Windows, D3D12 Mobile renderer

## ผล

Import ผ่าน และ test scripts ทั้ง 9 ชุดผ่านโดยไม่พบ script/runtime errors หรือ assertion failures:

- startup_flow: threaded loading → menu → gameplay → Back ผ่าน
- fishing_simulation: 60 checks, 0 failures; เวลา landing ของ baseline ที่บันทึกไว้ตรงกันหลังแยกสูตร
- fish_catalog_fishing: 16 species, 0 failures
- fish_models: 530 checks, 0 failures
- refactor_boundaries: 21 checks, 0 failures
- collection, fishing_visual, fish_render, water_render: 0 failures ทุกชุด

ตรวจภาพ HUD, catch result และสมุดสะสมที่ render จริงแล้ว รวมถึงผล responsive checks ของชุดทดสอบ ตรวจ `res://` paths ใน authored scenes/scripts/resources ไม่พบไฟล์หาย

Python tooling compile ผ่าน, release verifier แสดง CLI ได้ และ PowerShell build script parse ผ่านพร้อมอ่าน AAB preset/version 0.1.4 ได้ ไม่ได้เรียกขั้น signing หรือสร้าง Android release ใหม่

เรียกซ้ำด้วย `tools/run_tests.py --suite all --output exports/qa-refactor/final` พร้อม `--godot` หรือ `LAKEBOUND_GODOT`

หลักฐานอยู่ใน `exports/qa-refactor/final/results.json`, console/engine logs และ `screenshots/`; water test เก็บภาพของตนใน `exports/qa-water/`

## ข้อจำกัดที่บันทึกไว้

- Host แจ้งว่าอ่าน Windows root certificate store ไม่ได้ และ editor import เข้า signing directory ที่จำกัดสิทธิ์ไม่ได้ ข้อความเหล่านี้แยกไว้ใน `host_diagnostics`; ไม่มีการอ่านหรือเปลี่ยน signing material
- เมื่อปิด startup/navigation test Godot แจ้ง 10 ObjectDB instances leaked; verbose log ระบุ RefCounted reference count 0 ยังไม่ได้ยืนยันสาเหตุ ไม่พบ warning นี้ในชุดทดสอบอื่น บันทึกไว้ใน `warnings` และ `startup-verbose.console.log` โดยไม่อ้างว่าแก้แล้ว
- ยังไม่ตรวจ Android hardware, physical touch, safe area, vibration หรือ signed AAB ใหม่ ผล desktop tests ไม่ยืนยันสิ่งเหล่านี้

## สิ่งที่ส่งมอบ

แยก scene ที่แก้ใน Editor ได้สำหรับ pond, camera, effects, rod control และ catch result; session คุม pause/input ownership; geometry/tuning มีเจ้าของชัดเจน; fight calculation และ collection persistence ทดสอบแยกได้ คง save schema และการบันทึกตอน fish landed เดิม พร้อม README, architecture และ test runner ที่จำกัดเวลา/แยก QA profile
