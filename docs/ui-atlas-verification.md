# ผลตรวจ UI atlas — 23 ตุลาคม 2026

## ผลลัพธ์

ผิว UI ใช้ PNG ที่เจนด้วย built-in image_gen เพียงไฟล์เดียว: `assets/ui/atlas/modern_flat.png` มี 16 sprite regions ได้แก่พื้นผิว 6 แบบ วงกลมจอย 2 แบบ และไอคอน 8 แบบ ไม่มีการเซฟภาพย่อยสำหรับแต่ละปุ่ม

แนวภาพ modern flat สีกรมท่า/slate/mint มุมโค้ง เรียบ ไม่มีกรอบตกแต่ง ใช้ตัวอักษรจริงพร้อมฟอนต์ไทยเดิม สถานะปกติ/hover/pressed/disabled แยกด้วยสีและความสว่าง ปุ่ม secondary แยกจากพื้นพาเนลชัดเจน ปุ่มเริ่มเล่นและแท็บที่เลือกใช้ mint

เปลี่ยนเมนูหลัก HUD ร้านค้า สมุดปลา ภารกิจ ผลจับ Tutorial และแถบโหลดแล้ว ภาพฉากหลัง โลโก้ รูปปลา และรอก 3D เป็นเนื้อหาเดิม ส่วนแรงตึงที่เปลี่ยนค่าตลอดเวลายังคงวาดจากค่าจริง

## ขนาดที่วัดได้

| รายการ | ค่าจริง |
|---|---:|
| PNG ต้นฉบับจากเครื่องมือ | 1254×1254, 902,529 bytes (~881 KiB) |
| Texture ที่ Godot นำเข้า | 512×512 RGBA8 |
| งบเนื้อภาพบน GPU ไม่รวม overhead | 1,048,576 bytes (1 MiB) |
| .ctex ที่นำเข้าแบบ lossless | 179,502 bytes (~175 KiB) |
| mipmaps | ปิด |
| PNG ของผิว UI ใหม่ | 1 ไฟล์ |

AtlasTexture .tres เป็นพิกัดอ้างภาพเดียว ไม่ใช่สำเนารูป ส่วน StyleBoxTexture ใช้ PNG เดียวโดยตรงกับ region_rect เพื่อแบ่ง nine-slice ไม่มีการรับประกันจำนวน draw calls เท่ากับหนึ่ง เพราะ text, clipping, fish previews และ canvas order มีผลด้วย

เพิ่ม exclusion `assets/ui/modern/*.svg` และ `assets/ui/collection/*` ใน export presets ทั้งสาม หลังตรวจว่า scene/script ที่ใช้งานไม่มีการอ้างรูปเก่าเหล่านี้ ภาพเก่ายังอยู่ใน source สำหรับย้อนดู

## การตรวจที่ผ่าน

- Godot 4.7.2 import/parse ผ่าน ไม่มี script/resource error ของ UI ในรอบสุดท้าย
- `ui_atlas_test.gd` รอบสุดท้าย 90 checks ผ่าน: texture ขนาด 512, alpha, regions ไม่พ้นขอบ, ทุก theme style ใช้ PNG ร่วม, PNG เดียว, export exclusions ทั้งสาม preset, ฉากยังโหลดได้ และพื้นจอยมาจาก atlas
- `ui_atlas_visual_test.gd` รอบสุดท้าย 28 checks ผ่าน: ภาพจริงของ 8 หน้าจอที่ 1280×720 และ 1600×720 รวม modal/pause, ปุ่มภารกิจ/ร้านค้า/สมุด และปล่อยปลาจากหน้าผลจับ
- ชุด regression รวม import + 27 suites ผ่าน 28/28 entries: `exports/qa-ui-atlas/final/results.json` รวม UI ใหม่ ภารกิจ เศรษฐกิจ Tutorial startup flow multi-touch และชุดตกปลา/ภาพเดิม
- หลังเพิ่มการตรวจ export exclusions และภาพ loading รันทดสอบเฉพาะสองชุด UI ซ้ำ ผลอยู่ที่ `exports/qa-ui-atlas/atlas-console.log` และ `visual-console.log`
- ตรวจภาพด้วยสายตา: ปรับมุมปุ่มที่ยุบ กรอบพาเนลที่หนา พื้นปุ่มที่กลืนกับพาเนล และแถบ progress ที่หายจาก nine-slice ให้เรียบร้อยก่อนส่งมอบ
- พบ ObjectDB warning จาก fixture ที่เปิด threaded loading แล้วปิดก่อนรับผลโหลด แก้ fixture ให้รับผลก่อนปิด และทดสอบซ้ำโดยไม่มี warning นี้

Godot มี host diagnostic เรื่อง root certificate store และการอ่าน signing directory ในบางคำสั่ง แยกจาก script error ตาม test runner เดิม การทดลอง export-pack ทั้งโปรเจกต์หยุดอยู่ในขั้น Packing โดยไม่สร้าง pack จึงหยุดเฉพาะ process ทดสอบนั้น ไม่ถือว่า export ผ่าน งานนี้ยังไม่ได้ยืนยัน Android APK/AAB หรือเครื่อง Android จริง

## ไฟล์สำหรับปรับต่อ

- `assets/ui/atlas/atlas_manifest.json`: พิกัดต้นฉบับและ import_size
- `assets/ui/atlas/generation-prompt.txt`: prompt เต็มและที่มาภาพ (built-in image_gen)
- `tools/build_ui_atlas_resources.py`: สร้าง .tres และ Theme จากพิกัดที่ตรวจแล้ว ไม่สร้างภาพซ้ำ
- `assets/ui/modern/hud_theme.tres`: Theme ของเกมเพลย์และเมนูย่อย
- `shared/ui/game_theme.tres`: Theme ของเมนูหลักและหน้าจอโหลด
- ฉากเดิมทั้งหมดแก้ layout และข้อความได้ใน Godot Editor

ถ้าปรับพิกัดหรือ import_size ให้รัน builder แล้ว import ใน Godot และตรวจ region/UI อีกครั้ง อย่าเปลี่ยน size_limit เพียงอย่างเดียว เพราะพิกัดจะไม่ตรงกับ texture ที่นำเข้า

ภาพส่งมอบอยู่ที่ `exports/qa-ui-atlas/screenshots/` และภาพ regression รอบรวมที่ `exports/qa-ui-atlas/final/screenshots/`
