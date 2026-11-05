# Lakebound WebRTC + Cloudflare TURN experiment

สถานะ 3 พฤศจิกายน 2026: ตัวทดลองนี้ทดสอบ Cloudflare TURN แบบบังคับ relay ผ่านแล้ว และนำ WebRTC ไปเชื่อมเกม Lakebound พร้อม Supabase signaling/Edge Function แล้ว ดูสถานะเกมและข้อจำกัดล่าสุดใน [competition-webrtc.md](../../docs/competition-webrtc.md) ส่วนโฟลเดอร์นี้ยังเป็นห้องทดลองแยกและไม่รวมในไฟล์ส่งออกเกม

## ทดลองตอนนี้โดยไม่สมัคร

รันจากโฟลเดอร์นี้:

```powershell
node server.cjs
```

เปิด http://127.0.0.1:43840/?room=36271 สองหน้า แล้วกด **เข้าห้อง / สร้าง** ทั้งคู่ ปิด **บังคับ TURN** ไว้ก่อน ตัวละครวงกลมจะเดินอัตโนมัติ ส่งพิกัดผ่าน WebRTC DataChannel เป้าหมาย 20 Hz; ปิดเดินอัตโนมัติเพื่อใช้ลูกศรหรือคลิกตำแหน่งได้ อัตราจริงอาจลดเมื่อ browser จำกัดหน้าที่อยู่เบื้องหลัง

หน้าแสดงคู่ที่เชื่อมแล้ว แพ็กเก็ตส่ง/รับ RTT และเส้นทาง ICE: `host ↔ host` เป็นเชื่อมตรงบนเครื่อง/เครือข่ายที่เข้าถึงกันได้, `srflx` เป็น NAT mapping, `relay` เป็น TURN ค่า RTT บนเครื่องเดียวไม่แทนผลเล่นบนอินเทอร์เน็ต

บริการ Node ฟังเฉพาะ 127.0.0.1 จึงเปิดจากมือถืออีกเครื่องไม่ได้ ยังไม่ใช่บริการจับคู่ผ่านอินเทอร์เน็ต มีไว้แลก SDP/ICE ภายในเครื่องและออก TURN credentials ชั่วคราว ไม่มีตำแหน่ง คะแนน เซฟเกม หรือ Google token ผ่านบริการนี้ ไม่มีการแก้ตารางหรือค่าใดใน Supabase

## ส่วนที่ต้องสมัครเพิ่ม

1. สมัครหรือเข้า [บัญชี Cloudflare](https://dash.cloudflare.com/sign-up)
2. เปิด **Realtime → TURN** และสร้าง TURN key ตาม [เอกสาร Generate Credentials](https://developers.cloudflare.com/realtime/turn/generate-credentials/)
3. เก็บ **TURN Key ID** และ **TURN Key API Token** ฝั่งบริการเท่านั้น ไม่ใส่ใน HTML, Godot export, git หรือข้อความแชท
4. ปิด Node ตัวที่ยังไม่มีคีย์ก่อน แล้วรัน `./start-turn-lab.ps1` ใน PowerShell ของคุณ สคริปต์ถาม API token แบบซ่อนตัวอักษร และส่งคีย์ผ่าน environment ของ process เท่านั้น
5. เปิดหน้าทดลองใหม่สองหน้า เลือก **บังคับ TURN** ก่อนเข้าห้อง ต้องเห็นเส้นทาง `relay` และตัวนับรับเพิ่มขึ้น จึงถือว่าผ่าน TURN จริง การเชื่อมตรงผ่านไม่ได้ยืนยันว่า TURN ใช้งานได้

Cloudflare ระบุ STUN ฟรีไม่จำกัด และ TURN/SFU มี free tier รวม 1,000 GB/เดือน ก่อนราคา $0.05/GB ตาม [ราคา](https://www.cloudflare.com/plans/) และ [TURN FAQ](https://developers.cloudflare.com/realtime/turn/faq/) การเปิดบริการและขั้นตอน billing ให้เจ้าของบัญชีดำเนินการ; ตัวทดลองไม่ได้สมัครบริการหรือเปิดการเรียกเก็บเงินให้อัตโนมัติ

ตัว broker เรียก endpoint ทางการ `POST https://rtc.live.cloudflare.com/v1/turn/keys/{id}/credentials/generate-ice-servers` ด้วย `ttl=3600` คืนเฉพาะ `iceServers` ชั่วคราวให้ client และ cache ต่อ session ทดลอง ไม่ log token/SDP/ICE/IP การทดลองหนึ่ง session ควรไม่เกินหนึ่งชั่วโมง แล้วออก/เข้าใหม่เพื่อขอ credentials ใหม่ ยังไม่มี ICE restart/credential renewal อัตโนมัติ

## Godot native experiment

ใช้ skill godot-scene-first: UI อยู่ใน `godot/lab.tscn` ปรับใน Inspector ได้, transport อยู่ใน `godot/pose_peer.gd` ทั้งหมดเป็นโปรเจกต์ Godot แยก มี `.gdignore` ป้องกันเกมหลักนำ lab ไป import/export

ส่วนขยาย [godotengine/webrtc-native 1.2.1-stable](https://github.com/godotengine/webrtc-native/releases/tag/1.2.1-stable) เป็น GDExtension สำหรับ Godot 4.3+ ตาม release notes รองรับ engine 4.7.2 ที่ใช้ทดสอบ รัน `./setup-native.ps1` เพื่อดาวน์โหลดจาก repository ทางการและตรวจ SHA256 ที่บันทึกไว้:

`F37D03DA03DA3FF0D092542A04586644F889135CB7A1C3566AD57513203A553B`

ไฟล์ zip/addons binaries ไม่ติด git และไม่ติด build เกมหลัก หากจะนำไปใช้กับเกมจริงต้องรวม license/third-party notices จาก upstream ด้วย

```powershell
# แทน <godot> ด้วย path ของ Godot 4.7.2 executable
& <godot> --headless --path ./godot --editor --import --quit
& <godot> --headless --path ./godot --script res://native_test.gd
& <godot> --path ./godot
```

กด **Run local peer test** ในหน้าต่าง Godot: สร้างสอง WebRTCPeerConnection จริงและส่งข้อมูลสองทิศทาง ใช้ signaling ในหน่วยความจำ ไม่ผ่าน Node/Supabase/Cloudflare ข้อทดสอบ `native_test.gd` เชื่อมครบ mesh 5 คน (10 คู่ / 20 peer connections) บนเครื่องเดียว ทดสอบ packet จริง, duplicate sequence, malformed data และ close

Godot native กับ browser ใช้ชื่อ channel `lakebound-pose`, negotiated id 0, unordered, maxRetransmits 0 และ JSON pose แบบเดียวกัน แต่ **ยังไม่ได้ทดสอบ native↔browser, Android จริง, Web export จริง หรือข้ามเครือข่าย** ไม่มีการรับประกันความเข้ากันได้จนกว่าจะทดสอบชุดนั้น

## ผลที่ตรวจแล้ว

- Node: `node --test server.test.cjs` ผ่าน 2 suites ครอบคลุม short-lived credential request ด้วย mock, ไม่ส่ง permanent token คืน, configuration/error handling, 5 seats, room isolation, cross-origin rejection, authorization และปฏิเสธการส่ง pose ผ่าน signaling
- Godot Windows 4.7.2: native mesh ผ่าน 17 checks; UI render ทดสอบเปิด DataChannel จริง ส่ง/รับ 58/58 ต่อฝั่งในตัวอย่าง capture และปิดโดยไม่มี object leak
- Browser: 5 หน้าเชื่อมครบ 4 คู่ต่อหน้า ทั้ง 10 คู่เป็น `host ↔ host`, แต่ละหน้ารับส่งมากกว่า 1,000 packets; signaling รวมที่สังเกต 50 ข้อความตอนตั้ง mesh ไม่เพิ่มตาม pose แต่ control polling ยังเกิดตามปกติ
- Browser leave/rejoin เชื่อมกลับได้ และบังคับ TURN เมื่อยังไม่มีคีย์แสดงข้อผิดพลาดแทนแอบกลับไป direct
- ภาพ Godot ตรวจแล้วที่ `test-results/native-lab.png`
- **ยังไม่ผ่าน TURN จริง** เพราะยังไม่ได้ตั้งบัญชี/คีย์ Cloudflare การทดสอบ mock ไม่แทนการเชื่อมต่อ relay

## แผนนำไปเชื่อม Lakebound

1. ทดลอง TURN แบบบังคับ relay และ 2 เครื่องคนละเครือข่าย เก็บ selected candidate type, RTT, loss, disconnect/rejoin และ usage Cloudflare จริง
2. ทดสอบ Windows↔Web และ Android↔Web ด้วย channel/schema เดียวกัน รวม background/foreground และเครือข่ายเปลี่ยนระหว่างเล่น
3. เพิ่ม feature flag transport adapter ในเกม โดยให้ Google auth, room membership, fish ownership, scoring อยู่ที่ Supabase เดิม ส่งเฉพาะ pose ผ่าน DataChannel
4. ย้าย signaling ไป private Supabase room channel พร้อม session/round nonce, targeted messages, bounded ICE batching และตรวจ sender จาก authenticated membership ฝั่งบริการ; ผูก remote player ID กับลิงก์ที่ยืนยันแล้ว ไม่เชื่อ ID ที่มากับ packet อย่างเดียว
5. ออก credentials ผ่าน Supabase Edge Function ที่ตรวจ Google JWT และ active room membership มี rate/cost limit และ server-side secrets ตัว local broker นี้ไม่ควรนำขึ้น public โดยตรง
6. ทำ reconnect/ICE restart และ bounded queues/backpressure บน native; จัดการ credential expiry; ปิดทุก link เมื่อออกห้องหรือเปลี่ยนรอบ
7. สำรองด้วย Supabase Broadcast ได้เฉพาะอัตรา/เพดานที่จองงบไว้เดิม ห้าม fallback 20 Hz ลง Supabase และห้ามเพิ่มห้องพร้อมกันก่อนจัดงบ fallback ใหม่
8. เมื่อผ่าน acceptance จึงเปิดหลายห้องแบบขั้นบันได คง 2–5 คนต่อห้องก่อน เพราะ full mesh ใช้จำนวนคู่ n(n−1)/2 และ bandwidth เพิ่มตามจำนวนคู่ ไม่ใช่รองรับคนในห้องไม่จำกัด

## อ้างอิงหลัก

- [Godot WebRTC](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html): native ต้องใช้ GDExtension; Web มี implementation ของ browser
- [Godot WebRTCPeerConnection](https://docs.godotengine.org/en/stable/classes/class_webrtcpeerconnection.html): negotiation, polling และ channel options
- [Cloudflare Generate Credentials](https://developers.cloudflare.com/realtime/turn/generate-credentials/): long-lived key อยู่ server, แจก expiring ICE credentials
- [Cloudflare TURN FAQ](https://developers.cloudflare.com/realtime/turn/faq/): relay encrypted DataChannel, TTL/expiry, ICE restart, ราคา
