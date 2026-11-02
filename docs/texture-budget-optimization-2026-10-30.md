# Refactor และ optimize ขนาด — 30 ตุลาคม 2026

## เป้าหมายและขอบเขต

ลดรายละเอียดภาพที่เกินขนาดแสดงผลจริง โดยรักษาภาพสีต้นฉบับ โมเดล จำนวนแผนที่ ชนิดปลาและอุปกรณ์ไว้ครบ วัด AAB และดาวน์โหลดของ ARM64 ด้วยสเปกเดียวกันก่อน–หลัง แยกค่าดังกล่าวจากขนาดติดตั้งจริง/ข้อมูลแอป/แคชของ Android

## สิ่งที่ลงมือปรับ

| กลุ่ม | ค่า import ใหม่ |
|---|---:|
| Normal map สะพานและ reference rocks | 1024 |
| Roughness สะพานและ reference rocks | 512 |
| Atlas อุปกรณ์ 57 ชิ้น | 1024 (ช่องละ 128) |

SHA-256 ของ PNG ต้นฉบับทั้งห้าไฟล์ตรงกับก่อนทำงาน ใช้ Import Size Limit ลดเฉพาะไฟล์ที่เกมใช้จริง ไม่ย่อภาพต้นฉบับทับไฟล์เดิม Albedo และ geometry ไม่เปลี่ยน

รวมข้อกำหนดไว้ใน tools/texture_budget.json และ tools/apply_texture_budget.py:

- `python tools/apply_texture_budget.py --apply` ปรับค่า import และสร้าง AtlasTexture regions ใหม่จาก column/row ของ manifest ในพิกัดต้นฉบับ
- `python tools/apply_texture_budget.py --check` ตรวจทั้งหมด 63 รายการโดยไม่แก้ไฟล์
- หลัง --apply ให้ Godot reimport ก่อน build การเรียกซ้ำไม่ลดพิกัดซ้ำอีก เพราะคำนวณจาก source layout เสมอ
- manifest แยก cell_size ของ source (256) จาก runtime_cell_size (128) ชัดเจน

ยังคงซีน .tscn และค่า import ที่ปรับได้ใน Editor ไม่มีระบบสร้าง UI ใหม่ขณะรันเกม

## สิ่งที่พบและแก้ระหว่างตรวจ

- ไอคอนเงินในร้านค้าบนเว็บหายจาก nested scene-child overrides จึงบันทึก HBox/TextureRect/Label ตรงใน tackle_panel.tscn และเพิ่มการตรวจหลัง repack ซีน ตรวจ Web export จาก origin ใหม่เพื่อไม่ใช้ PWA cache รุ่นเก่าแล้วไอคอนแสดงครบ
- เครื่องมือ QA build ค้างที่ Windows console launcher หลัง export: tools/build_size_audit.py ใช้ headless engine โดยตรงเมื่อมี sibling .exe และเก็บ stdout ลงไฟล์ ผลสุดท้าย exit 0, timeout false

## ผลวัดจริง

หน่วย MB ฐานสิบ อ้างอิง AAB เดิม 0.1.20 เทียบ optimized-qa-final.aab ที่เซ็นด้วยคีย์ QA แยก ไม่มีการอัปโหลดหรือเปลี่ยน release version

| ตัวชี้วัด | ก่อน | หลัง |
|---|---:|---:|
| AAB | 93.52 MB | 85.81 MB |
| bundletool estimated download ARM64 | 66.74 MB | 59.04 MB |
| ผลรวมเนื้อหา APK หลังคลาย ZIP สำหรับ ARM64 | 160.68 MB | 145.20 MB |
| เนื้อหาเกมก่อน ZIP ใน AAB | 81.20 MB | 65.73 MB |

เนื้อหา APK หลังคลาย ZIP เป็นตัวชี้วัดเปรียบเทียบ payload ไม่ใช่การวัด Settings > Storage บนมือถือจริง ค่าก่อนทำใกล้กับ 161 MB ที่ผู้ใช้รายงาน แต่ยังไม่นับวิธีจัดเก็บของ OS, app data และ cache ดาวน์โหลดประมาณการวัดด้วย bundletool, ARM64/SDK35/density420/locale en เหมือนกันทั้งสองไฟล์

Native .so ทั้งสี่ไฟล์มี SHA-256 ตรงกับ baseline ไม่ตัด ABI และไม่เปลี่ยนตัว engine

## การตรวจผล

- Equipment catalog: **414 checks ผ่าน** รวม 57 ภาพไม่ว่าง มีขอบครบ พิกัดไม่เกิน atlas การเลือกอุปกรณ์และรอกทำงาน และภาพเงินยังอยู่หลัง repack ซีน
- รันชุด equipment อีกครั้งจาก install-time assets ที่แตกจาก **AAB สุดท้ายจริง**: **414 checks ผ่าน**
- Lure progress: **238 checks ผ่าน**
- HUD session: **45 checks ผ่าน**
- Texture budget: **62 checks ผ่าน** (5 ขนาด texture + 57 พิกัดภาพ)
- Visual fixture: **15 checks ผ่าน** เปิด 6 แผนที่และจับภาพก่อน–หลัง พร้อมภาพระยะใกล้สะพานและหิน; ตรวจจาก install-time assets ด้วย
- เทียบภาพระยะใกล้: mean absolute RGB difference สะพานประมาณ 1.45/255, หิน reference 0.45/255 ไม่ใช่การรับรอง pixel-identical เพราะมีน้ำ/ปลา/เอฟเฟกต์ในภาพ
- ตรวจภาพร้านที่ 1280×720 และ 2400×1080; ภาพอุปกรณ์ยังอ่านรูปทรงครบ ไม่มีช่องผิดหรือภาพตัด
- Web release export สำเร็จ ตรวจใน Chromium จริงแล้วภาพอุปกรณ์และไอคอนเงินแสดงครบ ไม่มี console error ในการตรวจร้านรอบสุดท้าย

ข้อจำกัด: ไม่มีมือถือ Android จริงสำหรับวัดขนาดติดตั้ง/FPS/RAM ไม่ได้เผยแพร่ Play หรือเว็บออนไลน์ การเรนเดอร์ ETC2 ของ AAB บน desktop มี warning แปลงรูปแบบ texture เป็น RGBA8 ตามฮาร์ดแวร์ และมี diagnostic certificate-store/user-directory ของ host; ชุดตรวจที่ระบุไม่มี SCRIPT ERROR หรือ FAIL

## ไฟล์สำหรับดูแลต่อ

- ข้อกำหนด: tools/texture_budget.json
- ซีนร้านค้า: features/economy/tackle_panel.tscn (Card/Content/Wallet)
- เครื่องมือ: tools/apply_texture_budget.py, tools/build_size_audit.py
- ทดสอบ: tests/texture_budget_test.gd, tests/texture_budget_visual_test.gd, tests/equipment_catalog_test.gd
- หลักฐานและตัวเลขละเอียด: exports/qa-optimize-2026-10-30/final-results.json, device-size.json, image-comparison.json
- ภาพเว็บ: exports/qa-optimize-2026-10-30/web-shop-final.png
- AAB สำหรับ QA เท่านั้น: exports/qa-optimize-2026-10-30/optimized-qa-final.aab

รอบนี้จบที่ค่าข้างต้นหลังตรวจภาพแล้ว ยังไม่ลด normal maps ชุดรองหรือภาพสีเพิ่มเติม เพราะต้องมีหลักฐานว่าคุ้มต่อคุณภาพก่อน
