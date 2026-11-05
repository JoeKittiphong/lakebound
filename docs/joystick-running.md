# เดิน วิ่ง และวิ่งอัตโนมัติ

ปรับ 4 พฤศจิกายน 2026 โดยคง HUD และจอยเป็นฉากที่แก้ใน Editor ได้

## พฤติกรรม

- จอยเดินใช้ตำแหน่งนิ้วจริงก่อน clamp: อยู่ในหรือบนขอบวงฐานเป็นเดิน ออกนอกวงเป็นวิ่ง ลากกลับเข้าเป็นเดิน ปล่อยแล้วหยุด ไม่มีการล็อกโหมดวิ่งจากจอย
- เส้นแบ่งอิงครึ่งหนึ่งของด้านที่สั้นที่สุดของจอยใน local coordinates จึงตามขนาด UI และ canvas scale ป้องกัน floating-point error ตรงขอบวง โดยยังคง deadzone และความเร็วเดินตามแรงโยกเดิม
- ปุ่มวิ่งเปิดวิ่งอัตโนมัติไปด้านหน้าตาม yaw ของกล้อง แม้ไม่แตะจอย ความเอียงกล้องไม่ลดความเร็ว ปุ่มแสดงสถานะกดและข้อความ “หยุดวิ่ง” กดซ้ำปิดและหยุดเมื่อไม่มี input อื่น
- ระหว่างวิ่งอัตโนมัติ จอยหรือคีย์บอร์ดเปลี่ยนทิศชั่วคราวโดยยังวิ่ง ปล่อยแล้วกลับไปวิ่งตามกล้อง
- เปิดเมนู เริ่มเล็ง/ตกปลา ลงน้ำ ขึ้นเรือ ปิดการควบคุม เสียโฟกัสหรือพักแอป จะยกเลิกวิ่งอัตโนมัติ ต้องกดเปิดใหม่ ปิดเมนูไม่ทำให้วิ่งต่อเอง
- Shift ค้างร่วมกับทิศทางยังใช้วิ่งด้วยคีย์บอร์ดได้ จอยคันเบ็ดและการขับเรือไม่เปิดวิ่งจากวงนอก

## แก้ใน Editor

เปิด `features/fishing/fishing_hud.tscn`:

- `SafeArea/MoveJoystick`: `run_outside_base` เปิดเฉพาะจอยเดิน ขนาด Control กำหนดขอบวงสำหรับวิ่ง ส่วน `radius` กำหนดระยะเลื่อนของ knob และแรงโยกเต็ม
- `SafeArea/MovementActions/LeftActions/Run`: ปุ่ม toggle และ tooltip อยู่ในฉาก สคริปต์อัปเดตเฉพาะสถานะกดและข้อความตามโหมด
- `SafeArea/MoveLabel`: คำแนะนำ “ในวงเดิน · นอกวงวิ่ง”
- ความเร็วอยู่ที่ `actors/player/player.tscn` ผ่าน `move_speed` และ `run_speed`

## การตรวจ

รันผ่านโปรไฟล์ทดสอบแยกจากเซฟผู้เล่น:

```powershell
node tools/test_competition.cjs joystick_run_visual camera_movement active_scene_movement boat_integration hud_session
```

- ชุดใหม่ `joystick_run_visual`: 134 checks ผ่าน บน Godot 4.7.2 Windows แบบ rendered มี viewport touch dispatch จริง ตรวจขอบวงทุกทิศหลัก/ทแยง การย้อนกลับเข้า การปล่อย การกดปุ่มซ้ำ กล้อง การแทรกทิศด้วยจอย focus/modal/fishing/input-disable น้ำ เรือ และ Sprint/Idle animation
- ภาพและผลอยู่ใน `exports/qa-competition/joystick_run_visual/` ตรวจภาพที่ 1024×768, 1280×720 และ 2400×1080 ปุ่ม active อ่านได้และไม่ทับจอย
- `camera_movement`: 62 checks ผ่าน; `active_scene_movement`: ผ่าน; `boat_integration`: 52 checks ผ่าน; `hud_session`: 45 checks ผ่าน
- ชุดเก่า `mobile_multitouch`: 2/261 failures เรื่อง eye/walking acquisition; `traversal_equipment`: 4/68 failures เรื่องโมเดลคันเบ็ด/ปลายคัน เทียบด้วยการย้อนเฉพาะการเปลี่ยนแปลงงานนี้ชั่วคราวแล้วพบ failures เดิมครบทั้ง 6 จุด เก็บผลใน `../output/joystick-run-baseline.log` และคืนไฟล์หลังทดสอบแล้ว
- ยังไม่ได้ทดสอบโทรศัพท์จริงหรือเผยแพร่ Android/Web รุ่นใหม่
