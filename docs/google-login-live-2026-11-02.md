# ผลติดตั้ง Google Login และแมตช์จริง — 2 พฤศจิกายน 2026

## สิ่งที่ติดตั้งแล้ว

- Supabase Lakebound: migration 003–006, account ownership, match state machine และ private channel RLS
- ติดตั้งและรีเซ็ตใน transaction เดียว Guard ตรวจข้อมูลก่อนล้างเป็น 18 ผู้เล่น / 412 สถิติ
- สำรองครบในตาราง private ที่มี RLS และไม่มี API grants; players/scores เป็น 0 หลัง reset
- ภายหลังล็อกอินจริงเกิดบัญชี Google ใหม่ตามปกติ ไม่ใช่ข้อมูล guest เดิมที่ถูกนำกลับมา
- OAuth client: `Lakebound Supabase Login`, Web application ในโปรเจคเดิม `eighth-epigram-381815`
- Google provider เปิดใน Supabase; client secret เก็บใน provider เท่านั้น ไม่ใส่ในเกม/repository
- Additional redirect URLs ตรงกับโค้ด: Android custom scheme และ Windows loopback port 43827
- OAuth Audience: External / Testing มีบัญชีทดสอบ 2 บัญชีตามที่เจ้าของอนุมัติ

## การตรวจออนไลน์

1. SQL smoke บน production จำลอง JWT claims ของสองตัวตนใน transaction แล้ว rollback:
   account binding → create/join → ready → loading barrier → countdown → score → duplicate → finish ผ่าน
   หลัง rollback ตรวจ players/scores/accounts/rooms ไม่มี fixture จาก transaction นี้
   นี่เป็นการตรวจ backend บนบริการจริง ไม่ใช่การล็อกอิน Google ของสองคน
2. HTTP จริง: public board 200 และไม่มีสถิติเดิม; guest-only upload คืน google_login_required;
   account/match RPC ที่ไม่มี JWT คืน 401 / permission denied
3. Windows Godot QA client แยก APPDATA จากเซฟผู้เล่น: Google OAuth PKCE กลับเข้าเกมจริงผ่าน
   account_ready, identity validation, account save namespace และ refresh token presence ผ่าน
4. ปิดและเปิด QA client ใหม่ เซสชัน Google restore ได้ ไม่ต้องเลือกบัญชีซ้ำ
5. Private Realtime สอง connections ของบัญชีเดียวเข้าห้องสำเร็จ ส่ง pose ผ่าน Broadcast ถึงอีก socket
   topic ที่บัญชีไม่ได้เป็นสมาชิกถูกปฏิเสธ และปิดห้อง QA เมื่อเสร็จ

หลักฐานในเครื่อง: `exports/qa-competition/google-live-login-result.json` (มีเฉพาะ booleans ไม่มี token/email),
`exports/qa-google-live/session1/realtime-final.log`, ภาพหน้าล็อกอินใน `exports/qa-competition/`
สคริปต์ opt-in: `tests/google_live_login.gd`, เปิดด้วย `LAKEBOUND_GOOGLE_LIVE=1`
ต้องแยก APPDATA/LOCALAPPDATA และปิด background ranking ระหว่าง QA ตามการรันครั้งนี้

## สิ่งที่แก้จาก live test

Phoenix WebSocket ต้องใช้ join_ref เดียวกันตั้งแต่ phx_join จนถึง Broadcast
ก่อนแก้ server ยอมรับ join แต่ทิ้งข้อความที่ตามมาเพราะ join_ref ไม่ตรงกัน
แก้ใน `MatchRealtime.protocol_message` และเพิ่ม regression สองข้อ
ตรวจ native live transport ซ้ำแล้วทุก boolean ผ่าน รวม nonmember_topic_rejected

## ขอบเขตและการตัดสินใจ

- Automatic approval review ปฏิเสธการสร้างโปรเจคใหม่เพราะการเพิ่ม resource/ใช้ quota ยังไม่อนุญาตเฉพาะ
  จึงใช้โปรเจคเดิมที่ OAuth ยังไม่เคยตั้งค่า แทนการสร้างใหม่
- Review ปฏิเสธการปิด public access ทั้ง Realtime project เพราะจะ disconnect clients ทั้งหมด
  ยกเลิกการเปลี่ยน global setting แล้ว ใช้ private=true ใน client และ RLS ของห้องตามที่ live test ตรวจผ่าน
- ไม่ได้ทดสอบการแข่งขัน 2–5 บัญชี Google จริงพร้อมกันหรือ Android physical-device redirect
  ตรวจ gameplay/local regressions และ Android Java/manifest compile แล้ว; ขั้นต่อไปใช้ Gmail ที่เพิ่มไว้เข้าทดสอบจริง
- QA transport ใช้สอง sockets ของบัญชีเดียว ไม่อ้างว่าเป็นผู้เล่นสองคน
- ห้อง QA ที่ออกแล้วอยู่ในสถานะ cancelled ไม่มีห้องทดสอบ active ค้าง
