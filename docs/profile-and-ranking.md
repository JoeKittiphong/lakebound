# โปรไฟล์และกระดานอันดับ Lakebound

สถานะ 2 พฤศจิกายน 2026: ย้ายตัวตนและอันดับไป Supabase แล้ว เกมรุ่นเดิมใช้ URL เดิมผ่าน compatibility bridge
ดู [แผนย้ายและผลทดสอบ](supabase-migration.md) และ [API ปัจจุบัน](../services/supabase/README.md)
เนื้อหาด้านล่างเป็นบันทึกระบบ Sheets เดิมสำหรับการอ้างอิงและกู้คืน

ปรับปรุงเดิม 28 ตุลาคม 2026: ใช้ Google Sheets ผ่าน Google Apps Script เท่านั้น
ซอร์สบริการอยู่ใน `services/google_sheets/` และไม่มี Python API หรือ SQL backend
ในตัวเกมอีกต่อไป ดู [API และวิธีดูแล](../services/google_sheets/README.md)

## การเก็บข้อมูลและขอบเขต

เกมบันทึกโปรไฟล์ เงิน อุปกรณ์ สมุดปลา และคิวกู้คืนผลจับในเครื่องก่อน
เปิดเล่นแบบออฟไลน์ได้ การเปิดกระดานอันดับจึงค่อยส่งสถิติที่ดีที่สุดซึ่งยังไม่ถูกยืนยัน
ต่อคู่แผนที่/ชนิดปลา ครั้งละไม่เกิน 100 รายการ ไม่ส่งทุกครั้งที่จับปลา
Google Sheets เก็บตัวตน guest และคะแนนดีที่สุด ไม่ใช่สำเนาเซฟทั้งเกม
การขายหรือปล่อยปลาไม่ลบสถิติตลอดกาล

ID และ token สุ่มอยู่ใน `user://angler_profile_v1.cfg`; การเปลี่ยนชื่อไม่เปลี่ยน ID
ไม่ต้องใช้ Gmail ของผู้เล่น ยังไม่มีระบบกู้บัญชีเมื่อผู้เล่นลบเซฟหรือเปลี่ยนเครื่อง
ค่าสถิติส่งจาก client จึงยังไม่ใช่ผลการแข่งขันที่รับรองป้องกันโกง

## หน้าจอและขอบเขตโค้ด

| ไฟล์ | หน้าที่ |
|---|---|
| `features/social/social_panel.tscn` | หน้าตา รายการ ปุ่ม และ HTTPRequest ที่มีขนาด/เวลา/redirect จำกัด |
| `features/social/social_panel.gd` | เปิด/ปิดหน้าจอ รับ input จัดลำดับคำขอและ retry |
| `sheets_connection_settings.gd` | อนุญาตเฉพาะ Google Web App URL; อ่านการตั้งค่าเดิมอย่างปลอดภัย |
| `sheets_ranking_sync.gd` | delta upload, acknowledgement, conditional version และ cache |
| `ranking_snapshot.gd` | ตรวจ compact schema ให้ HTTP และ cache ใช้กติกาเดียวกัน |
| `services/google_sheets/Code.gs` | ตรวจสิทธิ์ guest เขียน Sheets และสร้าง snapshot อันดับ |

แก้รูปร่าง UI ได้ใน scene ก่อน Play มีหมวดอันดับรวมและแยกแผนที่ 6 แห่ง
เลือก Top10/50/100 ได้ หนึ่งแถวต่อผู้เล่น เรียงน้ำหนักเป็นกรัมมากไปน้อย
เมื่อเท่ากันใช้เวลาจับก่อน แล้ว player ID/catch ID ตามกติกาของ Apps Script
ไม่มี pagination ของ API เก่าหรือหมวดออนไลน์แยกชนิดปลา

ขณะหน้าจอซ่อน การเปลี่ยนโปรไฟล์จะทำให้สถานะออนไลน์หมดอายุโดยไม่สร้างแถวใหม่
เมื่อเปิดใหม่จะแสดงข้อมูลปัจจุบันและ cache ที่มี แล้วจึงขอข้อมูลล่าสุด
ถ้าไม่มีอันดับของตัวเองใน Top ที่ได้รับ จะแสดงสถิติในเครื่องโดยไม่สร้างอันดับขึ้นเอง

## คำขอและความปลอดภัย

ค่าเริ่มต้นอยู่ใน `online.cfg` section `[sheets]`
ผู้เล่นเปลี่ยนได้เฉพาะ `https://script.google.com/macros/s/<deployment-id>/exec`
ไม่มี username/password, query token, custom HTTP API หรือ localhost fallback
บันทึก override ใน `user://sheets_connection.cfg`
อ่าน `server_connection.cfg` เดิมได้เฉพาะกรณีเป็น URL ของ Sheets อยู่แล้ว
URL ของบริการเก่าจะถูกข้ามไปใช้ค่าที่แพ็กมากับเกม โดยไม่แก้ตัวตนหรือข้อมูลผู้เล่น

token อยู่ใน POST body ผ่าน HTTPS เท่านั้น การอ่านคะแนนที่ไม่มีข้อมูลใหม่ใช้ GET
ตาม redirect เฉพาะ Google content host ด้วย GET ใหม่ที่ไม่มี body/headers ของ POST
ปิด automatic redirects และจำกัดข้อมูลตอบกลับ 256 KiB กับเวลา 15 วินาที

ยืนยัน upload เฉพาะ HTTP 200 และ response ที่ตรวจผ่าน ข้อมูลผิดรูปจะไม่เขียนทับ
cache ที่ดีและไม่ล้างรายการที่ต้องส่งใหม่ ตรวจชนิดข้อมูล จำนวนแถว เวอร์ชัน
player ID ชื่อ ชนิดปลา แผนที่ กรัมจำนวนเต็ม และลำดับ/ผู้เล่นซ้ำ
cache บนดิสก์ใช้ตัวตรวจเดียวกัน อัปโหลดซ้ำหลัง write failure ต้องทำได้โดยไม่เพิ่มคะแนนซ้ำ

Apps Script ใช้ script lock, hash ของ guest token และ escape ข้อความที่จะลง cell
เพื่อไม่ให้กลายเป็นสูตร โดยตรวจชนิด ID/token ก่อนใช้ regex
ไม่มีการคืน token หรือ hash ในอันดับ Keep spreadsheet และ Script Properties เป็นส่วนตัว
Apps Script ยังมี quota และยังไม่มี public abuse rate limiter หรือ account recovery

## ตรวจและเผยแพร่

```powershell
node services/google_sheets/test-ranking.cjs
python tools/run_tests.py --godot <godot-console.exe> --tests sheets_ranking_sync sheets_settings ranking_snapshot social_lifecycle
python tools/run_tests.py --godot <godot-console.exe> --tests ranking_maps cached_ranking social_visual sheets_settings_visual --rendering-method mobile
```

ชุดด้านบนไม่เขียนข้อมูลขึ้น Google ชุด `sheets_live_http` เป็น opt-in read-only
ต้องกำหนด `LAKEBOUND_QA_URL` และไม่รวมใน suite all ส่วน `http_smoke.py`
สร้าง guest จริง จึงควรรันกับ QA deployment ที่ตั้งใจเลือก

การแก้ `Code.gs` ใน repository ไม่อัปเดต deployment ของ Google โดยอัตโนมัติ
ต้องนำ source ที่ตรวจแล้วไปอัปเดต Apps Script เมื่อพร้อมเผยแพร่
ผลตรวจรอบนี้อยู่ใน [refactor-2026-10-28.md](refactor-2026-10-28.md)

