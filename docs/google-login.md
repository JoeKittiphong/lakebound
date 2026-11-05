# Google Login และการเริ่มข้อมูลผู้เล่นใหม่

สถานะ 2 พฤศจิกายน 2026: ติดตั้ง migration 003–006 และรีเซ็ต production แล้ว
สำรองและนำข้อมูลเดิม **18 players / 412 scores** ออกจากตารางใช้งานใน transaction เดียว
สร้าง Google OAuth client `Lakebound Supabase Login` ในโปรเจคเดิม `eighth-epigram-381815`
เปิด Google provider และตั้ง Android/Windows redirect URLs ใน Supabase แล้ว
ล็อกอินจาก Godot ผ่าน Google กลับเข้าเกมจริง การ restore session และ private Broadcast ผ่าน
ดู [ผลตรวจออนไลน์จริง](google-login-live-2026-11-02.md)

## พฤติกรรมผู้เล่น

- หลังล็อกอิน บัญชีที่ยังใช้ชื่ออัตโนมัติ `นักตกปลา <รหัส 6 ตัว>` จะต้องตั้งชื่อเอง 2–24 ตัวอักษรก่อนเข้าเล่นออนไลน์
- บันทึกชื่อด้วย Google JWT ผ่าน RPC เดิม แล้วโหลดตัวตนจาก Supabase ยืนยันก่อนเข้าเกม; หากบันทึกไม่สำเร็จลองใหม่ได้
- บัญชีที่มีชื่อกำหนดเองแล้วจะไม่ถูกถามซ้ำ หน้าตั้งชื่อแก้รูปลักษณ์ได้ใน `features/auth/login_panel.tscn`
- เปิดเกมใหม่เห็นหน้า “เข้าสู่ระบบด้วย Google” หรือเลือกเล่นออฟไลน์ได้
- เลือกบัญชี/อนุญาตผ่านเบราว์เซอร์ของ Google เกมไม่มีช่องรับรหัสผ่าน Google
- Google → Supabase → authorization code กลับเข้าเกม → แลกเซสชันด้วย PKCE S256
- หลังยืนยันเซสชัน ยังเข้าแมตช์ไม่ได้จน account RPC คืนตัวตนเกมที่ผูกกับ auth.uid
- บัญชี Google ใหม่สร้างโปรไฟล์ใหม่ ไม่ย้าย guest ID เงิน อุปกรณ์ หรือสมุดปลาเดิม
- กลับมาบัญชีเดิมใช้ player ID เดิม ออกจากระบบกลับไปโปรไฟล์ออฟไลน์ที่แยกกัน
- แมตช์และการอัปโหลดอันดับต้องใช้ Google JWT และข้อมูลยืนยันโปรไฟล์ที่ตรงกับบัญชี
- อ่านกระดานอันดับแบบ public ได้ โดยไม่ส่งอีเมลหรือ credential ของผู้เล่น
- เกมรุ่นเก่าที่ไม่มี Google JWT จะอัปโหลดสถิติเก่ากลับมาไม่ได้หลังติดตั้ง migration 006

บัญชี Google ในระบบนี้ผูกตัวตน ชื่อ อันดับ และการแข่งขัน
**ยังไม่ใช่ cloud save ของเงิน/อุปกรณ์/ความคืบหน้าทั้งเกม**
เล่นบนเครื่องใหม่จะได้ identity ออนไลน์เดิม แต่ความคืบหน้าภายในเครื่องเริ่มใหม่

## Scene และไฟล์สำคัญ

| ไฟล์ | หน้าที่ |
|---|---|
| `features/auth/login_panel.tscn` | หน้าล็อกอินที่แก้ layout/สี/ข้อความใน Editor ได้ |
| `features/auth/account_auth.tscn` | Autoload AccountAuth และ HTTPRequest ที่จำกัดขนาด/เวลา |
| `features/auth/account_auth.gd` | OAuth, callback, refresh, account binding, แยกเซฟ |
| `features/auth/oauth_pkce.gd` | สุ่ม verifier, SHA-256 challenge, ตรวจ callback route |
| `platform/android/auth/LakeboundAuthBridge.java` | รับ callback code จาก Android intent ไม่ log URL |
| `tools/prepare_android_auth.cjs` | ติดตั้ง bridge เข้า template Android ที่ถูก ignore ใน Git |
| `services/supabase/migrations/202611020004_google_accounts.sql` | ผูก Google auth.uid กับ player identity |
| `202611020005_google_matches.sql` | บังคับเจ้าของบัญชีสำหรับแมตช์ |
| `202611020006_google_rankings.sql` | บังคับเจ้าของบัญชีสำหรับอัปโหลดอันดับ |
| `services/supabase/reset_players_for_google.sql` | reset ข้อมูลเกมพร้อมสำรองและ guard กันรันซ้ำ |

`prepare_export.ps1` เรียก Android preparation ก่อน export
bridge ใช้ JavaClassWrapper ของ Godot 4.7 ไม่มี dependency สำหรับ Google password/native credential SDK
main activity ใช้ singleTask และ callback intent filter เฉพาะ scheme/host/path
รองรับ cold start โดยเก็บ PKCE verifier ชั่วคราวใน app-private storage ไม่เกิน 180 วินาที

## การตั้งค่า Google/Supabase ที่ต้องทำจริง

ใช้ Google Cloud project เดิม **Google sheet API** (`eighth-epigram-381815`)
ซึ่งไม่มี OAuth configuration มาก่อน ตั้ง OAuth consent branding ชื่อ **Lakebound**
ไม่ได้สร้างโปรเจคใหม่หรือใช้โควตาโปรเจคเพิ่ม
ใช้เฉพาะ scope `openid`, `email`, `profile` ไม่มีสิทธิ์ Gmail inbox/Drive
เลือก OAuth client ประเภท **Web application** เพราะ Supabase เป็น OAuth broker
ไม่จำเป็นต้องสร้าง Android credential/SHA certificate สำหรับ browser PKCE flow นี้

Google Authorized redirect URI:

```
https://efxjvrywbivyolluvuyp.supabase.co/auth/v1/callback
```

นำ Client ID และ Client Secret ไปใส่ Supabase Google provider เท่านั้น
ไม่ใส่ client secret/service-role key ในเกม, online.cfg, repository หรือ log
เปิด Google provider โดยไม่เปิด Skip nonce checks และไม่เปิด Allow users without an email
ไม่ต้องเปิด Anonymous Sign-ins อีกต่อไป

Supabase Additional Redirect URLs ต้องมี:

```
com.zylaah.lakebound://auth/callback
http://127.0.0.1:43827/auth/callback
```

Windows editor/test build ใช้ loopback listener เฉพาะ 127.0.0.1 ชั่วคราวระหว่างล็อกอิน
Android ใช้ custom URI กลับ Activity เดิม แล้วแลก authorization code ด้วย verifier ในเกม
รุ่น Web รองรับ same-tab PKCE redirect ผ่าน `features/auth/web_oauth.gd` แล้ว
ต้องเพิ่ม exact redirect URLs ใน Supabase ก่อนเผยแพร่ build นี้:
`https://lakebound-zylaah.netlify.app/` และ `https://lakebound-zylaah.netlify.app/index.html`
เก็บ verifier ใน localStorage ของ origin เดิมไม่เกิน 10 นาทีเพื่อรองรับ PWA ที่เปิดเบราว์เซอร์ภายนอก
รับ callback ครั้งเดียว ลบ query จาก URL และตรวจ route/PKCE ก่อนแลก token
ไม่อนุญาต deploy preview domains; ไม่เก็บ access token ใน adapter นี้
3 พฤศจิกายน: Supabase มี exact web callback ทั้งสองรายการแล้ว
พบ runtime parse errors ในเว็บจาก dependency manifest เก่า ทำให้ AccountAuth ไม่โหลดและปุ่ม Google กดแล้วเงียบ
`build_web.ps1` จึง import/audit และสร้าง manifest เฉพาะ Web ใหม่ทุกครั้ง
ตรวจแพ็กจริงด้วย `tools/check_web_pack.gd` (แยก APPDATA และปิด background services):
โหลด main menu, auth classes และตรวจสัญญาณ Google button ผ่าน
Web bridge คืนสถานะเป็น string ก่อนเปลี่ยนหน้าใน event loop ถัดไป เพื่อไม่ให้ navigation
ตัดการคืนค่าจาก WebAssembly และทำให้ client ล้าง pending ที่ยังใช้งานอยู่
หน้าเมนูไม่ยกเลิก pending เมื่อเบราว์เซอร์เปลี่ยนไป Google แต่ปุ่ม Cancel ยังล้างตามเดิม
Live test ยืนยัน Google callback และ token exchange ผ่าน พบ gzip response ถูก browser
คลายแล้วแต่ HTTPRequest คลายซ้ำเมื่อเปิดโปรไฟล์ จึงตั้ง accept_gzip=false เฉพาะ Web
ใน auth/cloud/match/ranking requests (native ใช้ค่าเดิม)
logic tests ผ่าน; ยังไม่ได้ทดสอบบนโทรศัพท์จริง

ผลตรวจเว็บ production 3 พฤศจิกายน 2026: กด Google จาก canvas ได้จริง เลือกบัญชีทดสอบเดิม
กลับมาที่ production ผ่าน PKCE, token exchange สำเร็จ และหลังแก้ HTTP gzip เปิดโปรไฟล์ได้
ตรวจหน้า Account แสดง “เข้าสู่ระบบแล้ว” พร้อมปุ่มออกจากระบบ/กลับเข้าเกม
ปิด–เปิดหน้าเกมใหม่แล้วบัญชีเดิมเชื่อมกลับได้ ไม่ล้าง site data หรือเซฟ
หลักฐาน: `exports/qa-web/google-profile-loaded-2026-11-03.jpg`
Regression: auth 33, startup 5, transport 12, cloud sync 223, background ranking 20 checks ผ่านทั้งหมด
ทดสอบ JS adapter และ exported-pack smoke check ผ่านแยกจากชุดข้างต้น
ผลนี้เป็น desktop browser ไม่ใช่การรับรอง installed PWA บน Android/iOS จริง
บน deploy ล่าสุด `6ae92af8501016557474bcc6` ทดสอบ Google login ใหม่และรีโหลดต่อเนื่องผ่าน
เซสชันเก่าจากรอบก่อนแก้เคย restore ไม่สำเร็จหนึ่งครั้ง ต้องเข้าสู่ระบบใหม่; ไม่ได้ล้างเซฟ
หลักฐานรอบล่าสุด: `exports/qa-web/google-latest-restored-2026-11-03.jpg`

Google consent อยู่ใน Testing เพิ่มบัญชีเจ้าของและ Gmail ผู้ทดสอบที่ผู้ใช้ระบุแล้ว รวม 2 บัญชี
เมื่อมีผู้ทดสอบเพิ่ม ให้เพิ่มอีเมลใน Google OAuth Audience ก่อน
ห้ามอ้างว่าผู้ทดสอบ 20 คนเข้าได้แล้วก่อนตรวจ audience/test users จริง

## การรีเซ็ตข้อมูล

ในเครื่องใช้ generation ใหม่ `user://accounts_v1/<auth-uuid>/` และ `accounts_v1/offline/`
มี profile.cfg, collection.cfg และ tutorial.cfg แยกกัน เซฟ guest เก่าไม่ถูกนำเข้าหรือเขียนทับ
cache/ack อันดับใช้ namespace Google ใหม่ เพื่อไม่แสดง cache เก่าเป็นข้อมูลบัญชีใหม่
refresh token เก็บใน app-private `google_session_v1.cfg`; access token อยู่ในหน่วยความจำ
การออกจากระบบลบเซสชันในเครื่อง ไม่รับรองการเพิกถอน JWT ที่ออกไปแล้วทันที

Production order: migration 003 → 004 → 005 → 006 → reset script
reset script จะหยุดหากจำนวนเปลี่ยนจาก 18 players / 412 scores, มีบัญชี Google/ห้องใหม่
หรือมี backup ของการ reset ครั้งก่อนแล้ว การ reset production ครั้งนี้เสร็จแล้ว ห้ามรันซ้ำ
ภายใน transaction สำรอง players/scores เป็นตาราง private ที่มี RLS และไม่มี API grants
จากนั้นเคลียร์เฉพาะ players/scores ไม่ลบ species catalog, config, source code หรือ assets
สำรองจริงอยู่ใน `lakebound_private.reset_20261102_players` และ `reset_20261102_scores`

## ผลตรวจ

- Godot auth logic 20 checks: RFC PKCE vector, callback ปลอม/ซ้ำ, Google-only session,
  account binding, fresh profile, การแยกบัญชี, refresh, offline และ revoked session
- หน้า login 6 checks ที่ 960×540, 1280×720, 1600×720 และตรวจภาพ render แล้ว
- Startup 5 checks: login ก่อนชื่อ, offline กลับเมนูได้, แมตช์บังคับ login
- PostgreSQL 56 checks: reset/backup/รันซ้ำ, Google ownership, protected ranking และแมตช์ครบวงจร
- Ranking core เดิม 29 checks (owner-only core หลังห่อด้วย Google gateway)
- Match integration, token retry, HUD, tutorial, startup และ social lifecycle ผ่าน
- Android `compileStandardDebugJavaWithJavac` ผ่านด้วย JDK 17 / Godot 4.7.2 template
- ล็อกอิน Google จริงบน Windows และกลับเข้าเกมผ่าน PKCE, restore session หลังเปิดใหม่ ผ่าน
- private Realtime จริงสอง connections ของบัญชีเดียว รับ Broadcast และปฏิเสธ topic นอกสมาชิก ผ่าน
- แก้ Phoenix join_ref ให้ตรงระหว่าง phx_join/Broadcast จากบั๊กที่พบใน live test และเพิ่ม regression
- ยังไม่ได้ทดสอบ redirect บนโทรศัพท์ Android จริง หรือแข่งพร้อมกัน 2–5 บัญชีจริง
- Sandbox Godot tests แจ้งอ่าน Windows certificate store ไม่ได้; ชุดเหล่านี้ไม่ใช้ผลนั้นรับรอง HTTPS จริง

ทดสอบซ้ำ:

```
node tools/prepare_android_auth.cjs
node tools/test_competition.cjs google_auth google_auth_visual google_startup competition_session competition_transport
node services/supabase/test_matches.cjs
node services/supabase/test_database.cjs
```

อ้างอิง: [Supabase Google login](https://supabase.com/docs/guides/auth/social-sign-in/auth-google),
[PKCE](https://supabase.com/docs/guides/auth/sessions/pkce-flow),
[Godot JavaClassWrapper](https://docs.godotengine.org/en/stable/classes/class_javaclasswrapper.html).
