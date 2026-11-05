# มุมกล้องระหว่างตกปลา

ปรับ 4 พฤศจิกายน 2026

ปุ่ม `SafeArea/PerspectiveButton` ใน `features/fishing/fishing_hud.tscn` เลือกมุมสำหรับการตกปลาและจำไว้ตลอดฉาก ไม่ใช่ตัวบอกมุมกล้องขณะเดิน เมื่อเลือก `1st` ระหว่างเดิน ตัวละครยังอยู่ในกล้อง 3rd และแสดง 1st ตามค่าที่เลือกไว้

| สถานะ | กล้อง |
|---|---|
| READY / เดิน / เล็ง | 3rd |
| CASTING / เบ็ดกำลังลอย | 3rd ให้เห็นอนิเมชันเหวี่ยง |
| WAITING / BITE / FIGHT | ตามปุ่ม 1st หรือ 3rd เปลี่ยนระหว่างตกปลาได้ |
| RESULT / LOST / เก็บเบ็ดกลับ READY | 3rd โดยจำค่าที่เลือกไว้สำหรับครั้งต่อไป |

`features/gameplay/gameplay.gd::_refresh_fishing_perspective()` แยกค่าที่เลือก `fishing_first_person` จากกล้องที่ใช้งานจริง ตรวจสถานะก่อนเรียก `camera_rig.set_fishing_view()` กลไกเดิมยังจัดการกล้องปัจจุบัน ตัวละคร คันเบ็ดมุมแรก และตำแหน่งปลายสาย

ทดสอบด้วย Godot 4.7.2 Windows และโปรไฟล์แยกจากเซฟจริง:

```powershell
node tools/test_competition.cjs perspective_cast_visual detailed_equipment_camera match_hud_layout minimap_hunt_visual
```

- `perspective_cast_visual`: 25 checks ผ่าน รวมทัชปุ่ม เหวี่ยงผ่าน controller จริง เบ็ดลงน้ำ เก็บเบ็ด การจำค่ารอบถัดไป ทุกสถานะ และการคืนตัวละคร/คันเบ็ด
- `detailed_equipment_camera`: 307 checks ผ่าน กล้อง อุปกรณ์ คันเบ็ด เอ็น และความถูกต้องของตัวละคร
- `match_hud_layout`: 36 checks ผ่าน รวมกติกากล้องเดียวกันในแมทช์
- `minimap_hunt_visual`: 87 checks ผ่าน รวมคำอธิบายสีแบบปุ่ม `?`
- ตรวจภาพเรนเดอร์ระหว่างเหวี่ยง หลังเบ็ดลงน้ำ และหลังเก็บเบ็ดใน `exports/qa-competition/perspective_cast_visual/`
- ยังไม่ได้ทดสอบโทรศัพท์จริงหรือเผยแพร่ Android/Web รุ่นใหม่
