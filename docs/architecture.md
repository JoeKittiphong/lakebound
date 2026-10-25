# Runtime architecture

> เอกสารขอบเขตจาก refactor รอบก่อน: ปัจจุบัน session มี economy, boats,
> missions และ regions เพิ่ม การเข้าถึง HUD ภายในจาก session ถูกแทนด้วย API แล้ว
> ใน [refactor phase 1](refactor-phase1-verification.md)
> ดูผลสำรวจซอร์สจริงและแผนแก้ล่าสุดที่ [refactor-roadmap-2026-10.md](refactor-roadmap-2026-10.md)
> อย่าใช้ข้อความ ownership ด้านล่างเป็นหลักฐานว่าทุก boundary ถูกบังคับครบแล้ว

## Ownership

```text
Gameplay session
 ├─ World (Pond) ─ PondDefinition
 ├─ Player ─ walking/rod presentation
 ├─ CameraRig ─ follow + camera gesture ownership
 ├─ PondEcosystem ─ population + bait reservation
 ├─ FishingController ─ state transitions + fight outcomes
 │   ├─ FishingTuning (configuration)
 │   └─ FightSimulation (per-session numeric state)
 ├─ FishingEffects ─ authored line/bobber/ripple/audio + visual pool
 └─ HUD ─ signals expressing player intent
     ├─ RodControl
     ├─ CatchResult
     └─ CollectionPanel ─ CollectionRow instances

FishCollection (Autoload) ─ statistics + save status
 └─ CollectionStore ─ ConfigFile IO and schema validation
```

`gameplay.gd` เชื่อม peers และคุม pause/navigation ไม่เข้าถึงโหนดภายใน HUD หรือ Player ฉากลูกดูแล layout, animations และ nodes ภายในของตัวเอง

Player และ CameraRig รับ reference ที่บันทึกใน gameplay scene ส่วน gameplay จ่าย input จาก HUD ให้ Player, bind HUD กับ controller/ecosystem และให้ ecosystem ใช้ PondDefinition เดียวกับ World

## Fishing and fish data

คง enum ordering เดิม: READY, WAITING, BITE, FIGHT, RESULT, LOST, CASTING

Controller คุม transition และ signals; `advance()` ยังใช้ทดสอบแบบ deterministic ได้ สูตรแรงปลา/รอก/ความตึงและการลด stamina อยู่ใน `FightSimulation.advance()` ซึ่งไม่มี SceneTree ส่วน controller บังคับขอบเขตน้ำและตัดสินสายขาด สายหย่อน สายหมด และขึ้นปลา

`FishState.position.y` เป็นความลึกบวก ไม่ใช่ความสูงของ visual ในโลก ข้อมูลชนิดปลาเป็น shared `FishSpecies` Resource; state, weight, hunger, stamina และ position เป็นข้อมูลปลาแต่ละตัว

PondDefinition ดูแล water constraint, walking constraint และ landing geometry; player/controller ไม่ฝังรูปทรงท่าเรืออีกต่อไป ระยะเวลาเหวี่ยงมีแหล่งเดียวใน FishingTuning; effects อ่าน normalized progress จาก controller

HUD เปลี่ยน visibility ตาม `state_changed`; ecology refresh เมื่อเปิด panel หรือ `population_changed`; tension, ระยะสาย และการตอบสนองต่อเนื่องยังอ่านต่อเฟรมได้ ไม่ต้องเพิ่ม event bus หรือ global singleton สำหรับ session

## Collection and persistence

บันทึกเมื่อ `fish_landed` ก่อนเลือก keep/release ครั้งเดียว จากนั้น gameplay ส่งปลาและ save status ให้ CatchResult แสดง การเก็บ/ปล่อยเปลี่ยนจำนวนปลาในบ่อ แต่ไม่บันทึก catch ซ้ำ

`FishCollection.record_catch_result()` คืนผลเป็นข้อมูล ส่วน `record_catch()` และข้อความเดิมยังเป็น façade ให้ผู้เรียกเดิมทำงานได้ `CollectionStore` ไม่มี UI และไม่มี SceneTree ใช้ schema version 1, species IDs เดิม และ `user://fish_collection.cfg` เดิม เขียน `.tmp` แล้ว rename เช่นเดิม; save version ที่ไม่รองรับจะบล็อกการเขียนทับ

CollectionPanel emit `opened`/`closed`; session เก็บ pause state ก่อนเปิดแล้วคืนเมื่อปิดหรือออกจาก session ไม่ให้ panel เปลี่ยนสถานะ pause ของทั้งเกมโดยตรง Grid ปรับเมื่อเปิด/resize; row เป็นเจ้าของภาพ silhouette ชื่อและสถิติของตัวเอง

## Verification

ใช้ `tools/run_tests.py` สำหรับ import, numerical/data tests และ rendered input/screenshot tests ดูคำสั่งใน `tests/README.md` ทุก process มี timeout และตรวจ script errors เพิ่มจาก exit code

ผลรอบ refactor อยู่ใน `exports/qa-refactor/final/` โดยแยก host diagnostics ออกจากเกม มีข้อจำกัด sandbox ในการเข้าถึง signing folder และ Windows root certificate store; รายละเอียดคงอยู่ใน logs

ดูผลตรวจครบและ warning ที่ยังไม่ได้ยืนยันสาเหตุใน [refactor_verification.md](refactor_verification.md)

ยังต้องตรวจ multi-touch, safe area, back/focus, vibration และ save/reopen บนอุปกรณ์ Android จริง รวมถึง export bundle ใหม่ก่อนนำ release ไปใช้
