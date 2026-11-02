# คัน รอก เอ็นชุดใหม่ และมุมตกปลาบุคคลที่หนึ่ง

โมเดลใหม่แทนฉากอุปกรณ์เดิมแล้ว คงรหัสอุปกรณ์เดิมและค่ากลไกของเดิมไว้เพื่อให้เซฟเดิมใช้ได้
คันใหม่ครบ 12 ตระกูล รอกครบ 8 ตระกูล และวัสดุเอ็น 4 กลุ่ม
เพิ่มรายการที่ขาด 9 รายการ: คัน spincast/tenkara/boat/feeder/ice, รอก round/lever drag/inline ice และสาย fly
รายการเดิมบางชิ้นเป็นรุ่นย่อยที่ใช้โมเดลตระกูลเดียวกัน เช่น light_rod ใช้ spinning
รอก electric เดิมใช้ภาพรอก lever drag ซึ่งเป็นตระกูลใกล้เคียงในชุดนี้ ยังไม่มีโมเดล electric เฉพาะ

## เลือกใช้
เปิดร้าน/อุปกรณ์ กดรับอุปกรณ์ทดลอง แล้วเลือกหมวดคันเบ็ด รอก และเอ็น แตะเลือกใช้
ปุ่มทดลองเพิ่มของผ่านระบบเดิมโดยไม่เปลี่ยนเหรียญ และไม่เปลี่ยนอุปกรณ์ให้อัตโนมัติ
ไม่แก้ไฟล์เซฟจริงระหว่างการพัฒนา/ทดสอบ

## กล้อง
READY: เห็นตัวละครและเดินตามปกติ
CASTING: ยังเห็นตัวละครเหวี่ยงเบ็ด
WAITING/BITE/FIGHT: กล้องที่ตัวละคร แสดงคัน รอก เอ็นชุดที่เลือก ซ่อนตัวละครและอุปกรณ์ที่มือในมุมเดิม
RESULT/LOST/READY: กลับกล้องเดิมและแสดงตัวละคร รวมกรณีเก็บสาย ยกเลิก ลงน้ำ และเปลี่ยนโหมดเรือผ่าน controller เดิม
เปิด UI ซ้อนยังหยุดเกมตามระบบเดิม มุมกล้องตกปลายังคงตามผู้เล่น/เรือ

## ฉากที่ปรับได้
`features/gameplay/camera_rig.tscn`: FishingCamera3D ปรับความสูง/FOV/near
`features/gameplay/fishing_equipment_view.tscn`: Socket ปรับตำแหน่งและมุมถือ; pump_degrees ปรับจังหวะยกคัน
`features/equipment/detailed/NN_family.tscn`: โมเดลคัน มือจับ จุดยึดรอก และ GuideLine
`features/equipment/detailed/reel_NN_family.tscn`: กลไกรอกและ FillSurface 64 tris
`features/equipment/detailed/rods.json`: จุดกึ่งกลางไกด์และ skin weights รวม snake guide ของ fly
`data/equipment/*.tres`: model_scene และ line_visual_style (mono/fluoro/braid/fly)

คันโค้งจาก tension ที่ระบบสู้ปลาคำนวณ ซึ่งมีน้ำหนักปลา/ความแข็งแรงอุปกรณ์อยู่แล้ว
เส้นภายในคันผ่านทุกไกด์ตาม skeleton เส้นนอกคันใช้ texture และสีเดียวกัน ต่อจากห่วงปลายคันจริงไปเหยื่อ/ปลา
รอกเคลื่อนไหวตามตระกูล: spinning หมุน rotor และเลื่อน spool, baitcasting/conventional/fly/ice หมุน spool; fly handle ติด spool
ฉากมุมใกล้ใช้สำเนาอุปกรณ์เพื่อไม่ให้ท่ามือของตัวละครบังหรือสั่นภาพ; ตัวละครมุมเดิมยังใช้ skeleton และ hand IK เดิม

## ตรวจสอบ
`tests/detailed_equipment_camera_test.gd`: คันครบ 12 แบบ รอกครบ 8 แบบ วัสดุ 4 แบบ และวงจรกล้อง/เส้นเอ็น
`tests/rod_equipment_test.gd`: การจับคัน/IK/การเปลี่ยนคันทุกชิ้นในท่า cast/reel/fight
`tests/equipment_catalog_test.gd`: รายการ 66 ชิ้น เลือกจากร้าน เซฟ และ pivots รอก
`tests/previews/detailed_equipment_preview.gd`: render ภาพ WAITING/FIGHT/กลับมุมตัวละครไป output/game-new-equipment

## HUD และการคุมคัน (ปรับล่าสุด)
ระหว่าง CASTING/WAITING/BITE/FIGHT ซ่อน BaitDock, OrbitButton, BoatActions, ปุ่มเดิน/กระโดด และเมนูส่วนบน
ยังใช้จอยเดินและจอยคุมคันได้ ข้อความแจ้งเตือนอยู่กลางขอบบนภายใน SafeArea
สูตรเหยื่อแสดงเพียง Sequence และ Feedback ไม่แสดงหลอด/เปอร์เซ็นต์/ข้อความซ้ำ
เมื่อกลับ READY คืนปุ่มอุปกรณ์และปุ่มเรือตามสถานะจริง

FishingEquipmentView แยก visual_stick จากอินพุตจริง ใช้การตอบสนองแบบ critically damped ที่คำนวณตามเวลา
input_smooth_time=0.14, return_smooth_time=0.20; ปล่อยจอยใช้เวลาประมาณ 0.5–0.6 วินาทีเพื่อกลับเกือบถึงกลาง
HandleAnchor ใน fishing_equipment_view.tscn ยึดปลายด้ามไว้กึ่งกลางจอ; ไม่มีการเลื่อนทั้งคันไปตามขอบจอแล้ว
lateral_yaw_degrees=42 หมุนคันพร้อมการเบี่ยงซ้ายขวา ปรับค่าได้ใน Inspector ของ EquipmentView
DetailedFishingRod.set_pull_direction รับทิศแรงดึงจากตำแหน่งปลาจริง (แปลง depth เป็นตำแหน่งใต้น้ำ)
ทิศแรงถูกแปลงเข้าพิกัดกระดูก จึงไม่ผูกการงอเข้ากับค่าจอยซ้ายขวาโดยตรง

ตรวจใหม่: fishing_hud_motion_test 111 checks, lure_rhythm_test 238 checks, lure_control_test 72 checks,
boat_integration_test 52 checks ผ่านทั้งหมด พร้อมภาพ render ใน output/fishing-hud-motion
ทดสอบการคืนคันที่ 30/60/120 fps, ขอบจอ 1280x720/2400x1080/1024x768, การคืนปุ่ม และแนวเอ็นทุกไกด์


## แก้จุดหมุนด้ามและระนาบไกด์
ปลายด้ามจริง (จุดต้นโมเดลคัน) ยึดกับ HandleAnchor ขณะคันหมุนรอบจุดนี้ทุกทิศ
Socket คำนวณตำแหน่งชดเชยจาก basis และระยะด้ามของคันแต่ละแบบ ไม่เลื่อนตำแหน่งด้ามตามจอย
แก้ทิศไกด์โดยคำนวณมุมรอบแกนคันจากตำแหน่งไกด์จริงและทิศแรงดึงที่ฉายลงระนาบตั้งฉากกับคัน
Model และ ReelMount หมุนด้วยกัน ก่อนแปลงทิศแรงเข้าสู่แกนกระดูกเพื่อคำนวณความโค้ง
guide_roll_speed=12 ปรับความเร็วการหมุนไกด์รอบแกนได้ โดยรักษาการเลื่อนมุมแบบต่อเนื่องผ่าน ±180 องศา

rod_pivot_pull_test: 487 checks ผ่าน ครบ 12 ตระกูล × 3 ทิศจอย × 3 ตำแหน่งปลา
ตรวจการเคลื่อนจริงของปลายคันเทียบกับทิศแรง การหันของไกด์จริง จุดด้ามคงที่ รอกหมุนกับคัน และเอ็นผ่านห่วง
fishing_hud_motion_test: ตรวจด้ามอยู่กึ่งกลางบนจอ 3 สัดส่วน พร้อมการคืนคันแบบนุ่มนวลที่ 30/60/120 fps
ภาพตรวจจริง: output/rod-pivot-alignment/left_edge.png, right_edge.png, right_fish_left.png, right_fish_right.png
