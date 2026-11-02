# Minimap และประวัติจุดตกปลา

พัฒนา 26 ตุลาคม 2026 ตามแชท “ออกแบบระบบ Minimap” และแผนในแชท “วางแผนระบบ minimap”

## วิธีใช้

- แตะแผนที่เล็กใต้กล่องปลาที่มุมขวาบน เพื่อเปิดแผนที่เต็มและพักเกม
- เปิดพื้นที่ทั้งหมดได้ตั้งแต่เริ่มเล่น ข้อมูลปลาปรากฏจากการจับสำเร็จของผู้เล่นเท่านั้น
- เลือกพื้นที่และชนิดปลา แล้วแตะจุดบนแผนที่หรือรายการประวัติด้านขวา
- จุดสีทองคือจุดปลากินเหยื่อ วงกลมขาวคือจุดยืนตอนนั้น เส้นเชื่อมแสดงทิศเหวี่ยง
- “กลับไปจุดยืนนี้” แสดงเป้าหมาย ทิศ และระยะบน Minimap; ถึงจุดภายใน 3 เมตรจะแจ้งถึงจุดหมาย
- แผนที่ใช้เหนือคงที่ หมุนเฉพาะลูกศรตามทิศตัวละครจริง การหมุนกล้องดูรอบตัวไม่เปลี่ยนทิศนี้
- กด +/− เพื่อซูม ลากเพื่อเลื่อน และ “ทั้งบ่อ” เพื่อกลับมุมมองรวม; เมาส์ใช้ wheel ได้
- “บันทึกจุดที่ยืน” สร้างจุดโปรดและตั้งชื่ออัตโนมัติ หรือเลือกตำแหน่งใดบนแผนที่แล้วกดเพิ่มจุดโปรด
- เลือกจุดโปรดแล้วลบได้ บันทึกซ้ำบริเวณเดิมภายใน 1 เมตรไม่สร้างรายการซ้ำ
- โน้ตเป็นทางเลือก จำกัด 240 ตัวอักษร กด “บันทึกโน้ต”; บันทึกข้อความว่างเพื่อลบ
- จากสมุดปลา ปลาที่ค้นพบแล้วมีปุ่ม “ดูจุดที่เคยจับ” เปิดแผนที่พร้อมตัวกรองทันที
- ดูพื้นที่อื่นได้โดยไม่เปลี่ยนฉาก หากต้องการนำทางต้องเข้าเล่นพื้นที่นั้นก่อน

ตำแหน่งประวัติไม่รับประกันว่าปลาชนิดเดิมยังอยู่ตรงนั้น ไม่มีการอ่านตำแหน่งปลาใน simulation มาแสดง
การนำทางเป็นทิศทางและระยะตรง ไม่ใช่เส้นทางเดินหลบสิ่งกีดขวาง จุดจากเรือระบุให้ใช้เรือกลับไป
เปิดแผนที่ได้เมื่อพร้อมตกปลา รอปลา หรือปลาหลุด ช่วงเหวี่ยง วัดเบ็ด สู้ปลา และหน้าผลจับจะไม่เปิดแทรก

## ฉากและค่าที่ปรับใน Editor

| ไฟล์ | ใช้ปรับ |
|---|---|
| `features/map/minimap.tscn` | กรอบ ขนาดแผนที่เล็ก ข้อความ ทิศเหนือ และ Terrain preview |
| `features/map/fishing_map_panel.tscn` | แผนที่เต็ม ตัวกรอง รายการประวัติ รายละเอียด โน้ต และปุ่มทั้งหมด |
| `features/fishing/fishing_hud.tscn` → `SafeArea/Minimap` | ตำแหน่งบน HUD; วางใต้กล่องปลาและเว้นปุ่มกลับ |
| `features/map/maps/*.tres` | ภาพพื้นแผนที่ ขอบเขต X/Z และ map ID ของทั้ง 6 พื้นที่ |
| `FishingMapView` ในทั้งสองฉาก | สีลูกศร ประวัติ และจุดยืน ผ่าน exported properties |
| `minimap.gd` → `update_interval` | ความถี่อัปเดตตำแหน่ง ค่าเริ่มต้น 0.1 วินาที |

ฉากหลักของ MapPanel เปิดแสดงใน Editor ได้โดยตรง ส่วน instance ใน HUD บันทึกให้ซ่อนไว้
Terrain เป็น TextureRect ที่ serialize ไว้ ภาพและ controls จึงมีอยู่ก่อนกด Play
สคริปต์วาดเฉพาะ overlay แผนที่และขับข้อมูล ไม่สร้างหน้าต่างหรือ layout ขึ้นใหม่

## ข้อมูลและเซฟเดิม

`FishingController` แช่ `bite_context` ณ ตอนปลากินเหยื่อ: `angler_xz`, `bite_xz`, `from_boat`
ใช้ X/Z ของโลก ส่วนความลึกเก็บใน `depth` เดิมซึ่งเป็นเมตรค่าบวก ไม่ใช้ Y ของตัวละคร
เมื่อจับสำเร็จ `CatchSettlement` เพิ่ม `location` ลง event เดิมและบันทึกผ่าน `profile.data.journal`
ใช้ `catch_id` เดิมสำหรับ retry/replay ทั้งเก็บและปล่อยปลาจึงมีประวัติเพียงครั้งเดียว

`profile.data.map_memory` เก็บข้อมูลผู้เล่นที่แก้ได้แยกจาก ledger:

- `favorites`: ID, map, position, from_boat, name; จำกัด 200 จุดรวมทุกพื้นที่
- `notes`: ข้อความตาม catch ID
- `next_spot`: ลำดับชื่ออัตโนมัติ

ยังใช้ไฟล์โปรไฟล์ v1 เดิม Loader เพิ่ม map_memory ที่ว่างให้เซฟเก่า ไม่มีการรีเซ็ตเงินหรือประวัติ
รายการเดิมที่ไม่มี location ยังคงอ่านได้และระบุ “ไม่มีพิกัด” โดยปิดการนำทางและเพิ่มจุดจากรายการนั้น
ข้อมูลชนิดผิด พิกัด NaN/Inf และข้อความเกินขนาดถูกปฏิเสธ การเขียนโน้ต/จุดโปรดล้มเหลวจะ rollback
ทั้งข้อความ รายการ และลำดับชื่อ โดยใช้กลไก atomic save ของโปรไฟล์เดิม

ประวัติแยกด้วย map และ species รายการแบ่งหน้าละ 100 แถวเพื่อเข้าถึงประวัติทั้งหมด
จุดใกล้กันรวมเป็นกลุ่มขนาด 32 screen units แต่ละกลุ่มเปิดรายการล่าสุดได้ และเลือกครั้งอื่นจากรายการด้านขวา
เก็บรายละเอียดทุกเหตุการณ์ไว้ครบ ไม่มีการตัด ledger เพื่อทำให้แผนที่เบา
Minimap แสดงเฉพาะจุดโปรดกับเป้าหมาย ไม่สแกนประวัติหรือ simulation ทุกเฟรม

## สร้างภาพแผนที่ใหม่เมื่อเปลี่ยนภูมิประเทศ

ใช้ Godot รุ่นเดียวกับโปรเจกต์:

```powershell
& $godotExe --headless --path . --script res://tools/build_fishing_maps.gd
& $godotExe --headless --path . --editor --import --quit
```

เครื่องมือสร้าง PNG ด้านยาว 512 px โดยรักษาสัดส่วนโลก อ่าน terrain definition จากฉากพื้นที่
ขอบเขตครอบคลุมทั้งน้ำและพื้นที่เดิน สะพานอ่านจาก definition และท่าเรืออ่าน transform ของฉากจริง
ไฟล์ PNG รวม 6 พื้นที่มีขนาดเล็ก ไม่เพิ่มกล้องหรือ viewport 3D ขณะเล่น
บนเครื่องทดสอบต้องแยก APPDATA/LOCALAPPDATA เหมือน runner เพื่อไม่ใช้เซฟจริง

## การทดสอบ

```powershell
python tools/run_tests.py --godot $godotExe --tests fishing_map_data fishing_map_visual --rendering-method mobile --output exports/qa-minimap/mobile-final
python tools/run_tests.py --godot $godotExe --tests catch_settlement economy hud_session refactor_boundaries collection mobile_collection mobile_multitouch optimization hud_performance regions_legacy_save --rendering-method gl_compatibility --output exports/qa-minimap/regression
```

- `fishing_map_data`: migration, frozen bite/stand, idempotency, note/favorite save/reload/rollback, corrupt input, reset, 6 maps, projection ทุก zoom และ clustering 10,000 records
- `fishing_map_visual`: ส่ง touch จริงผ่าน Viewport, เปิด/ปิด/pause, empty state, ภาพ 3 resolution, note/navigation/favorite, ทุกพื้นที่, drag, legacy, collection shortcut และ landed signal จริง
- หลักฐานและภาพอยู่ใน `exports/qa-minimap/` ซึ่งไม่เข้า Git

ตรวจบน desktop ด้วย Godot 4.7.2 ทั้ง Compatibility และ Forward Mobile/D3D12
การทดสอบ touch เป็นเหตุการณ์จำลอง ยังต้องตรวจ safe area, keyboard และสัมผัสบนอุปกรณ์ Android จริง
ไม่มีการ build/sign หรือส่ง release จากงานนี้

### ผลตรวจล่าสุด

วันที่ 26 ตุลาคม 2026:

| ชุดตรวจ | ผล |
|---|---|
| fishing_map_data | 43 checks, 0 failures |
| fishing_map_visual รอบสุดท้าย (Forward Mobile/D3D12) | 68 checks, 0 failures |
| boat_integration | 52 checks, 0 failures |
| catch_settlement, economy, hud_session, refactor_boundaries | ผ่าน |
| collection, mobile_collection, mobile_multitouch | ผ่าน |
| optimization, hud_performance, regions_legacy_save | ผ่าน |
| fishing_recovery, first_catch_tutorial, startup_flow | ผ่าน |

รวม 16 ชุดทดสอบที่เกี่ยวข้อง ผ่านทั้งหมดในรอบตรวจของงานนี้
ภาพ `boat-final/screenshots/` เป็นหลักฐาน Mobile renderer รอบท้าย รวมการขึ้นเรือจริง
ปรับ BoatActions ให้อยู่ทางซ้ายของ Minimap พร้อมเว้นพื้นที่ Jump และตรวจไม่ทับกันทั้ง 3 resolution
แก้ selection ของจุดโปรดที่ถูกลบไม่ให้ค้างบนแผนที่ และตรวจการเปิดสมุดปลา → แผนที่โดยไม่หลุด pause

Godot บน host มี diagnostic เรื่อง root certificate store และ editor scan ของ signing directory
runner แยกรายการเหล่านี้ไว้ใน `host_diagnostics` ผลผ่านข้างต้นตรวจว่าไม่มี script/runtime errors
