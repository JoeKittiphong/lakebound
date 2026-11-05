# แมตช์แข่งขันพร้อมกัน — รุ่นทดสอบ 2–5 คน

อัปเดต: ผู้ใช้เลือก Google Login และเริ่มข้อมูลใหม่แทน anonymous guest
ดูสถานะปัจจุบันและขั้นเปิดใช้งานใน [Google Login](google-login.md)
แผน Anonymous Sign-ins ด้านล่างเป็นบันทึกก่อนเปลี่ยนแนวทาง ไม่ต้องเปิดใช้งานตามส่วนนั้น

สถานะ 2 พฤศจิกายน 2026: ติดตั้ง Supabase จริงแล้ว ใช้ Google Login
ตรวจ Windows OAuth/restore และ private Realtime ผ่าน ดูผลออนไลน์จริงในเอกสาร Google Login
ยังไม่ถือว่าผ่านการทดสอบแข่ง 2–5 บัญชีจริงพร้อมกันหรือ Android physical device

## รูปแบบที่ทำ

อัปเดตล่าสุด: [ห้องด่วน เวลา กติกา และเพดานระบบ](competition-quick-matches.md)
รายละเอียด 600 วินาที/top-three ด้านล่างเป็นพฤติกรรมห้องรุ่นเก่าที่เก็บไว้เพื่ออ้างอิง

- ห้องส่วนตัว รหัสตัวเลข 5 หลัก (เก็บเลขศูนย์นำหน้า) เลือกได้จากสนามทั้งหก ไม่มีค่าสมัครหรือรางวัลทางเศรษฐกิจ
- ตัวละครเราและเพื่อนใช้ `actors/player/angler_visual.tscn` ร่วมกัน สเกลและจังหวะเดินจึงตรงกัน ปรับขนาดที่ฉากนี้จุดเดียว
- Migration `202611020010_five_digit_rooms.sql` เปลี่ยนรหัสห้องเดิมโดยคง UUID/สมาชิก/คะแนน และสุ่มซ้ำเมื่อรหัสชนกัน
- พร้อมครบ 2–5 คน เจ้าของเริ่ม → รอทุกเครื่องโหลด → นับถอยหลังร่วมกัน 5 วินาที
- แข่ง 600 วินาที ตกจากฝั่ง ชุดคัน/รอก/สายมาตรฐาน เลือกไส้เดือน แป้ง หรือเหยื่อปลอม minnow
- นับน้ำหนักกรัมรวมของปลา 3 ตัวที่หนักที่สุด ทุกชนิดในสนามนับคะแนน
- เสมอเทียบปลาตัวที่ 1, 2, 3 ตามลำดับ ถ้าเท่ากันทั้งหมดได้อันดับร่วม
- ผลต้องถึง RPC ก่อนเวลาจบตามฐานข้อมูล ไม่เชื่อเวลาจากเครื่องผู้เล่น
- ปลาที่จับนำออกจากประชากรรอบนั้น ไม่มีการขายหรือเก็บเข้ากระเป๋าปกติ
- เกมแข่งขันไม่ใช้ profile/เงิน/เหยื่อ/สมุดปลา/บทสอน/ประชากรปลาของเซฟหลัก
- หลุดแล้วเวลาเดินต่อ เข้าใหม่ผ่านห้องเดิมได้ คะแนนที่บันทึกแล้วอยู่ในฐานข้อมูล
- ออกจากห้องระหว่างแข่งถือว่าออกจากรอบ กลับเข้ารอบที่ล็อกแล้วไม่ได้
- เจ้าของหลุดเกิน 20 วินาที โอนให้สมาชิกที่ยังเชื่อมต่อเมื่อมีการเรียก state
- ห้องรอถอดผู้ที่ขาดการติดต่อเกิน 60 วินาที รอโหลดสนามเกิน 120 วินาทีจะยกเลิกรอบ
- ทุกคนหลุดไม่ต้องมี background worker: state ครั้งถัดไปตรวจเวลาและปิดรอบได้
- แข่งใหม่กับกลุ่มเดิม: ล้างคะแนน/พร้อม/โหลด เปลี่ยน seed และ round_id ทุกคนพร้อมใหม่

## ส่วนประกอบที่แก้ใน Editor ได้

| ไฟล์ | หน้าที่ |
|---|---|
| `features/competition/match_panel.tscn` | หน้าสร้าง/เข้าห้อง ห้องรอ ผลการแข่งขัน |
| `match_row.tscn` | หนึ่งแถวของสมาชิก/คะแนน |
| `match_hud.tscn` | เวลาที่เหลือ อันดับ ปุ่มเข้าห้อง และข้อความนับถอยหลัง |
| `remote_angler.tscn` | โมเดลตัวละครคนอื่นและป้ายชื่อ ไม่มี collision กับผู้เล่น |
| `match_tuning.tres` | ความเร็วรอก ความจุสาย และ tuning มาตรฐาน |
| `match_service.tscn` | autoload `Competition`, HTTPRequest ที่จำกัด timeout/body/redirect |
| `match_session.gd` | ผูก gameplay กับรอบ ส่งตำแหน่ง รับผลจับ ล็อกการเล่นตามเวลา |

ฉากแต่ละแผนที่มี `MatchSession` และ `MatchHUD` ที่ serialize ไว้
เมื่อเล่นปกติสองส่วนนี้ไม่ทำงาน ระบบเดิมยังใช้ AnglerSave ตามเดิม

## สัญญาข้อมูล

`POST /rest/v1/rpc/lakebound_matches` ใช้ publishable key และ Supabase Auth JWT
body `payload` มี `player_id`, `token`, `player_name`, `op` และค่าของ operation
RPC ยืนยัน guest เดิมผ่าน `lakebound_rankings` ก่อนเข้าถึงห้อง
ไม่ใช้ `user_metadata` เพื่ออ้างสิทธิ์ player ID และไม่ใส่ service-role key ในเกม

Operations: `create(map)`, `join(code)`, `state(room_id)`, `ready(room_id,ready)`,
`start(room_id)`, `loaded(room_id)`, `catch(room_id,round_id,catch_id,species,grams)`,
`leave(room_id)`, `rematch(room_id)`.

Snapshot schema 1: `id`, `round_id`, `code`, `host`, `map`, `phase`, `seed`,
`server_time`, `starts_at`, `ends_at`, `pose_interval`, `members`.
Member: `id`, `name`, `ready`, `loaded`, `departed`, `online`, `grams`, `best`, `rank`.

ห้องใช้ row lock เพื่อ serialize join/start/catch/leave ไม่เกิน 5 คนแม้เข้าพร้อมกัน
ผลจับ unique `(room_id,player_id,catch_id)` ส่งซ้ำไม่เพิ่มคะแนน เปลี่ยนข้อมูลเดิมถูกปฏิเสธ
round_id ป้องกันผลล่าช้าจากรอบเก่า client สร้าง catch ID จาก round_id และ fish ID
เพื่อให้จับปลาตั้งต้นตัวเดิมหลังโหลดใหม่เป็นการ retry ไม่ใช่คะแนนเพิ่ม
RPC จำกัด 200 ผลจับต่อผู้เล่นต่อรอบ ผลยังเป็น client-reported ไม่ใช่ anti-cheat simulation

## การรับส่งและโควตา

- Supabase Realtime **private Broadcast** topic `match:<UUID>` ใช้ส่งตำแหน่ง/มุม/ความเร็ว/สถานะตกปลา
- สมาชิกต้องมี auth.uid ที่ RPC ผูกกับ guest ที่ยืนยันแล้ว RLS ตรวจสิทธิ์ join/send/receive
- ค่า Broadcast เป็นภาพประกอบเท่านั้น ไม่ใช้ยืนยันคะแนน เวลา หรือสถานะห้อง
- รุ่นนี้ใช้ heartbeat จาก RPC state ประมาณทุก 3 วินาทีตรวจ online แทน Presence track
  เพื่อลด burst ข้อความเมื่อเข้าพร้อมกัน อันดับอัปเดตจาก RPC ไม่ใช่ทุกเฟรม
- ส่ง pose เมื่อขยับ/หมุน/เปลี่ยนสถานะ หรือ keepalive 3 วินาที สูงสุด 3 Hz
  ฐานข้อมูลคำนวณ interval เพิ่มตามผลรวมจำนวนสมาชิกแต่ละห้องยกกำลังสอง
  โดยตั้งเป้าข้อความ Broadcast เข้าและออกประมาณ 60 events/s ทั้งโปรเจค
  เผื่อ heartbeat และการ join แต่ไม่ใช่การรับประกันโควตาหรือความหน่วง
- Free จำกัด 100 messages/s ตามเอกสารที่ตรวจวันนี้; หลายห้องพร้อมกันจะเห็นการเคลื่อนไหวหยาบขึ้น
- TCP WebSocket และ interpolation ใช้กับตัวละครประกอบ ไม่ซิงก์ปลา สายเบ็ด ฟิสิกส์ หรือเรือ
- ยังไม่มี voice chat

อ้างอิง: [Realtime protocol](https://supabase.com/docs/guides/realtime/protocol),
[authorization](https://supabase.com/docs/guides/realtime/authorization),
[limits](https://supabase.com/docs/guides/realtime/limits),
[anonymous sign-ins](https://supabase.com/docs/guides/auth/auth-anonymous).

## เปิดใช้งานจริง — ขั้นที่ยังรอ

ตรวจ dashboard Lakebound แล้ว: `Allow anonymous sign-ins` ยังปิดอยู่
ก่อนเปิดให้ผู้ทดสอบต้องดำเนินการต่อไปนี้โดยเจ้าของโปรเจคหรือหลังยืนยันการเปลี่ยนสิทธิ์:

1. ติดตั้ง `services/supabase/migrations/202611020003_matches.sql` หลัง migration 001/002
   เพิ่มเฉพาะตาราง/ฟังก์ชัน/นโยบายของแมตช์ ไม่แทนฟังก์ชันอันดับเดิม
2. เปิด Authentication → Sign In / Providers → Allow anonymous sign-ins
   ผู้เล่นไม่ต้องกรอกอีเมล ใช้ session สำหรับ private Realtime ผูกกับ guest เดิมผ่าน RPC
3. Realtime Settings ปิด Allow public access เพื่อบังคับ private channels
   ก่อนเปลี่ยนให้ตรวจว่าไม่มี feature อื่นใช้ public channels (โค้ดเกมปัจจุบันไม่มี)
4. ทดสอบจริง 2 เครื่องก่อน แล้ว 5 เครื่อง: create/join/ready/loading/countdown/pose/score
   ปิดเน็ตหนึ่งเครื่อง เปลี่ยน host โหลดกลับ ส่งผลซ้ำ หมดเวลา และ rematch
5. ตรวจ Supabase Realtime logs/usage และ FPS บน Android ก่อนแจก build

การเปิด anonymous auth ทำให้บุคคลที่มี public project key ขอ session ได้
แต่เข้าห้องไม่ได้จน RPC ยืนยัน guest และสมาชิก การเปิดบริการนี้ยังมีความเสี่ยงต่อ signup abuse
ต้องประเมิน rate limits/CAPTCHA เมื่อขยายพ้นกลุ่มทดสอบ ไม่ใส่ CAPTCHA ที่ยังไม่มี client รองรับ

session refresh token และ room ID เก็บเฉพาะ `user://match_session.cfg`
access token อยู่ในหน่วยความจำ ไม่ log credentials ไม่เก็บตำแหน่งทุกเฟรมในตาราง
หากเกมปิดก่อนส่งผล ผลที่ยังไม่ยืนยันจะไม่กู้ข้ามการเปิดแอป ไม่มีการย้อนหลังเวลาเพื่อเพิ่มคะแนน
การลบเซฟ/เปลี่ยนเครื่องยังไม่ใช่ account recovery

## ทดสอบซ้ำ

```
node services/supabase/test_matches.cjs
node services/supabase/test_database.cjs
node tools/test_competition.cjs competition competition_transport competition_session competition_visual competition_play_visual
```

PostgreSQL ใช้ disposable loopback cluster; ไม่มีการเปลี่ยน production ระหว่างชุดเหล่านี้
`test_platform.sql` เป็น schema จำลอง Supabase สำหรับ local tests **ห้าม deploy**
Godot runner แยก APPDATA/LOCALAPPDATA ใน `exports/qa-competition/` และปิด background network
ภาพ entry/lobby/results มี 960×540, 1280×720, 1600×720; gameplay มีตัวละคร remote จำลอง
การผ่าน local tests ไม่ยืนยันว่า Auth/Realtime ของ cloud เปิดแล้วหรือรองรับ Android ผ่านเครือข่ายจริง

ผลตรวจล่าสุด:

| ชุด | ผล |
|---|---|
| PostgreSQL match RPC/RLS/concurrent join/rematch | 44 ผ่าน |
| PostgreSQL rankings เดิมร่วมกับ migration ใหม่ | 29 ผ่าน |
| Snapshot/pose validation/lobby | 14 ผ่าน |
| Session refresh/network retry/stale response | 11 ผ่าน (HTTP จำลอง) |
| Gameplay integration | 16 ผ่าน headless และ 16 ผ่าน Mobile renderer |
| UI 960×540, 1280×720, 1600×720 | 9 ผ่าน พร้อมตรวจภาพที่ render |
| HUD เดิม | 45 ผ่าน |
| Startup, social lifecycle, first-catch tutorial | ผ่าน |
| Fishing recovery/simulation | ผ่าน (simulation 60 checks) |

รันด้วย Godot 4.7.2; sandbox แจ้งอ่าน Windows certificate store ไม่ได้
ชุดในเครื่องไม่ได้ใช้ HTTPS จริง จึงไม่ใช้ผลนี้รับรองการเชื่อม Supabase
การเปิด scene ผ่าน UI ของ Editor ถูก dialog external-file changes ขวางและระบบจับภาพ timeout
จึงยืนยัน layout จากภาพที่เกม render และแหล่ง `.tscn` แทนการอ้างว่าได้ตรวจ Inspector แล้ว
