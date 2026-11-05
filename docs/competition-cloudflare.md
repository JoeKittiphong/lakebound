# ห้องแข่งขัน Cloudflare / เป้าหมาย 1,000 คนต่อวัน

สถานะ 3 พฤศจิกายน 2026: deploy แล้วที่ https://lakebound-matches.joe-star.workers.dev และเปิด `[match_edge] enabled=true` ใน `online.cfg` สำหรับเกมที่รันจากโปรเจกต์นี้ ยังไม่เผยแพร่ Android หรือ Web/PWA รุ่นใหม่

## ขอบเขตและเส้นทางข้อมูล

- Worker + SQLite-backed Durable Object `LakeboundMatches` ดูแลห้องห้าตัวเลข, หาห้องด่วน, รายชื่อ, ready/loading barrier, นับถอยหลังห้าวินาที, เวลาแข่งขัน, กติกาทั้งสามแบบ, สิทธิ์จับปลาและคะแนนรอบนั้น ย้ายทั้งเส้นทางนี้จึงไม่ติด `match_budget` ของ Supabase เดิม
- กดเล่นด่วนจะเข้าห้อง lobby ที่มี host ออนไลน์และที่ว่าง ถ้าไม่มีจะสร้างห้องค่าเริ่มต้น แม่น้ำ/10 นาที/น้ำหนักรวม ให้ทันที การเริ่มแข่งยังรออย่างน้อยสองคน ready และ host กดเริ่มตามระบบเดิม ไม่ได้เปิด auto-start
- เพดานเริ่มต้น 100 connections ที่ยืนยันตัวตนแล้ว, 20 ห้อง active, ไม่เกินห้าคน/ห้อง ตัวเลข 1,000 คนต่อวันเป็นเป้าหมายการใช้งานหมุนเวียน ไม่ใช่รองรับพร้อมกัน 1,000 คน
- ใช้ coordinator หนึ่ง Durable Object ที่มีหลายห้อง เพื่อคุมที่นั่ง/ห้องอย่างต่อเนื่องใน object เดียว ไม่มี lock/โควตา Realtime ข้ามกลับไป Supabase ทุกคำสั่ง เมื่อโตเกินเป้านี้ต้องแบ่ง coordinator เป็น shard พร้อมทดสอบใหม่
- Supabase ยังดูแล Google login, เซฟผู้เล่น/ความคืบหน้า และระบบอันดับถาวรเดิม ตัว RPC ใหม่ `lakebound_edge_identity()` คืนเพียง player ID, ชื่อที่ตั้งเอง และเวลาหมดอายุ ไม่คืน profile token ถาวร
- คะแนนระหว่างแข่งและ scoreboard เก็บแบบ durable ใน Cloudflare เป็นข้อมูลห้อง ไม่ได้เพิ่มระบบจัดอันดับแข่งขันถาวรใหม่ ห้องผลจบเก็บสูงสุดหนึ่งชั่วโมง/20 ห้องล่าสุดตราบที่ยังมีคนอยู่ หากทุกคนออกจะลบห้องทันที ไม่มีการลบเซฟหรือคะแนนเดิมใน Supabase

## การเชื่อมต่อและความปลอดภัย

1. เกมส่ง Supabase Google access JWT ผ่าน HTTPS ไป `/v1/session` Worker ส่งต่อให้ Supabase ตรวจลายเซ็น/บัญชีและเรียก identity RPC ด้วยสิทธิ์ผู้เล่น ไม่ใช้ service role
2. Worker ออก ticket อายุ 30 วินาที ใช้ได้ครั้งเดียว เก็บเฉพาะ SHA-256 ของ ticket ฝั่ง DO เกมส่ง ticket ในเฟรม auth แรกของ WebSocket ไม่ใส่ JWT/ticket ใน URL
3. ทุกคำสั่งใช้ตัวตนจาก connection ที่ยืนยันแล้ว ไม่รับ player ID/name/profile token ใน payload จากเกม ขอบเขตห้องและรอบตรวจทุกคำสั่ง รวมถึง SDP/ICE และตำแหน่งสำรอง
4. ต่อบัญชีมี socket ใช้งานหนึ่งอัน อันเก่าถูกปิด เมื่อถูกแทนที่ client จะไม่เชื่อมด้วย JWT เดิมวนแย่งกัน JWT หมดอายุถูกปฏิเสธใน handler; การ logout ปิด transport และล้างสถานะ client แต่ไม่ได้อ้างว่ายกเลิก JWT ทั่วระบบทันที
5. ใช้ Hibernation WebSocket API พร้อม auto-response ping/pong ทุก 25 วินาที ไม่มี timer ทุกเฟรมบน server และไม่เขียน SQLite ทุก heartbeat การพัก/คืน object ทดสอบแล้วว่ายังรักษาห้องและ attachments
6. ตรวจ frame ไม่เกิน 49,152 bytes, 12 คำสั่ง/วินาที/connection, RTC batch 16 รายการ, SDP 16k, bounded inbox/client buffer และเพดาน unauthenticated sockets แยกไว้ ตัวจำกัดระดับ connection ไม่ใช่ WAF/การกัน DDoS แบบครบระบบ

## WebRTC / TURN / กรณีเชื่อมไม่สำเร็จ

- ตำแหน่งยังวิ่งผ่าน WebRTC สูงสุด 20 Hz โดย signaling วิ่งผ่าน WebSocket ของ Cloudflare ไม่ poll ตาราง Supabase แล้ว
- ถ้า RTC ใช้ไม่ได้ ใช้ Cloudflare WebSocket สำรองทุกห้าวินาที เพื่อคุมการใช้โควตา เห็นการเคลื่อนไหวไม่ต่อเนื่องในโหมดนี้ การเล่นปกติควรเชื่อม RTC ได้ อย่าประเมินความลื่นจากโหมดสำรอง
- Worker Secrets: `CF_TURN_KEY_ID`, `CF_TURN_API_TOKEN` ผู้ใช้อนุญาตจัดเก็บแล้ว Credentials ชั่วคราวอายุหนึ่งชั่วโมง แคชประมาณ 55 นาทีต่อผู้เล่นใช้ข้ามรอบได้ จึงไม่ออกใหม่ทุกห้อง
- ป้องกันการออก credentials ถี่: 60 วินาทีระหว่าง attempts, ไม่เกินหก attempts/คน/วัน และ 3,000 attempts/วันทั่วบริการ จำกัดนี้ไม่ใช่เพดาน GB และไม่หยุดข้อมูลจาก credentials ที่ออกแล้ว
- native GDExtension เดิมรองรับ UDP TURN; ไม่รองรับ TCP/TLS TURN หากเครือข่ายบล็อก UDP อาจใช้ได้เพียง fallback ดูข้อจำกัดแพลตฟอร์มใน `competition-webrtc.md`

## ข้อมูลปลาและการบันทึก

สิทธิ์ปลาหนึ่งตัวตรวจใน coordinator เดียว ยึด species/grams จาก claim แรก, claim อายุ 90 วินาที, ต้องมี claim ID/round ตรงกันก่อนให้คะแนน การ retry catch เดิมไม่บวกซ้ำ/เปลี่ยนน้ำหนักไม่ได้ ปลาที่ขึ้นแล้วไม่กลับไปกัดเบ็ดคนอื่น

จำกัด 20 claims ที่ยังไม่ขึ้นปลา และ 200 catches รวมต่อห้องต่อรอบ เพื่อคุมขนาด state; ต่างจากระบบเดิมที่เพดาน catch สูงกว่า เมื่อถึงขีดจำกัดจะไม่ให้ claim เพิ่ม คำสั่งที่เปลี่ยนสถานะต้องบันทึกสำเร็จก่อนตอบและ push หาก write ล้มเหลวจะกู้ state จาก durable storage และคืน `busy_retry` โดยไม่รับรองคะแนนที่ยังไม่บันทึก

## ค่าใช้จ่ายและการเปิดรับ

ไม่ได้เปลี่ยน Workers เป็นแพ็กเกจเสียเงิน และไม่ได้เพิ่มโควตาหรือปิดเพดาน billing เดิม Cloudflare TURN ที่เปิดไว้แยกต่างหากยังคิดส่วนเกินตามแพ็กเกจของมัน

Workers/DO Free มีโควตารายวันหลายมิติ โดยเฉพาะ DO requests 100,000/วัน, compute 13,000 GB-s/วัน และ SQLite writes 100,000 rows/วัน การเขียน claim/renew/catch มีต้นทุนจริง การกดเล่นได้โดยไม่จองงบทั้งรอบจึงไม่ได้แปลว่าฟรีไม่จำกัด เมื่อบริการชนโควตาฟรีอาจคืน error และหยุดรับงานวันนั้น

ประเมินตัวอย่าง 1,000 คนเล่นคนละหนึ่งชั่วโมง: ถ้าจับคนละ 30 ตัวและไม่ต่ออายุ claim จะมี claim+catch ราว 60,000 mutations ก่อนรวม ready/start/leave/cleanup หากจับคนละ 60 ตัวจะมีราว 120,000 mutations ซึ่งอาจเกินโควตา writes ฟรี แม้ requests ยังพอ ต้องวัด Usage จริงก่อนรับรองเปิด 1,000 คนทุกวัน ข้อมูลราคา: https://developers.cloudflare.com/durable-objects/platform/pricing/

ดู Metrics ของ Worker และ Durable Objects รวมกับ TURN Usage โดยเน้น daily requests, rows written, errors, duration และ GB ห้ามเปิด paid plan อัตโนมัติ ไม่มีการแจ้งเตือนงบหรือ hard GB cap เพิ่มในงานนี้

หยุดรับห้อง/ผู้เล่นใหม่: ตั้ง Worker var `ACCEPTS_NEW=false` แล้ว deploy; รอบที่ยังอยู่เล่นต่อได้ ลด `MAX_PLAYERS`/`MAX_ROOMS` ใน config ได้ภายในขอบเขต 100/20 ของรุ่นนี้ หากลดเพดานต้องระวังการเชื่อมกลับและ rematch ของผู้เล่นเดิม

Rollback client: ตั้ง `[match_edge] enabled=false` และ restart กลับ Supabase เดิม (4 ห้อง/20 คน พร้อมงบจองเดิม) ห้อง Cloudflare ไม่ย้ายอัตโนมัติไปฐานข้อมูลเดิม และแยกรหัส backend ในเซฟ session เพื่อไม่กู้ห้องผิดระบบ

## ผลทดสอบ

- Node/workerd: ห้าชุดผ่าน รวม 100 WebSocket จริงใน runtime ภายในเครื่อง, 20 ห้อง, 100 state requests พร้อมกัน, กันข้ามห้อง/ปลอมผู้ส่ง RTC, ticket ใช้ซ้ำไม่ได้, session takeover และการคืนสถานะหลัง hibernation
- Registry: จำลองผู้ใช้หมุนเวียน 1,000 คนโดยไม่มีการจองโควตา Supabase พร้อมทดสอบกติกา/นับถอยหลัง/แย่งปลา/จับซ้ำ/restore/rematch
- Godot สองโปรไฟล์กับ workerd ในเครื่อง: เริ่มรอบ, mesh WebRTC จริง, แย่งปลาตัวเดียวกันแล้วให้คะแนนรวมเพียง 2,345 กรัม, ไม่เปิด Supabase Realtime ผ่านทั้งคู่
- บัญชี Google จริงสองบัญชีกับ Worker ที่ deploy: ผ่านทั้งคู่ รับ/ส่ง RTC 95–96 packets, `backend=cloudflare`, `supabase_realtime=false`, ไม่มี fallback pose รับเข้า ไม่มี service error หลังแก้ startup
- Database regression/identity: 205 checks ผ่านบนคลัสเตอร์ชั่วคราว Identity RPC ใหม่ deploy production แล้ว
- Client regression: RTC 19, transport 12, competition session 19, Google auth 33, room options 33 ผ่าน รวม 116 checks ในชุดที่รันรอบนี้ Export dependency audit รวม Edge scene/script แล้ว (1,885 export resources)
- การทดสอบ 100 connections เป็น local runtime ไม่ใช่ load certification บน Cloudflare จริง ยังไม่ทดสอบ 100 เครื่องต่างเครือข่าย, Android หรือ Web/PWA release ใหม่

## อัปเดตการคืนห้อง 4 พฤศจิกายน 2026

- เมื่อผู้เล่นคนสุดท้ายกดออก หรือ server ตรวจพบว่า WebSocket ของทุกคนปิดแล้ว จะลบห้องจากหน่วยความจำและ durable storage ทันที คืนทั้งที่นั่งและรหัสห้อง รวมถึงล้าง claims/catches ของรอบนั้น ไม่รอเวลาการแข่งขันสิ้นสุด
- ห้องที่ไม่มีคนแล้วไม่สามารถ resume/join ด้วยรหัสเดิมหรือ rematch รอบเดิมได้ กดเล่นด่วนจะจัดห้องใหม่ให้
- เผื่อ reconnect 75 วินาทีเฉพาะกรณียังมีผู้เล่นออนไลน์คนอื่นอยู่ในห้อง การสลับ session ของบัญชีเดียวกันไม่ทำให้ห้องปิดหาก socket ใหม่ยืนยันแล้ว
- ตรวจห้องว่างจากข้อมูลเดิมตอนคืนสถานะ object ด้วย และบันทึกการลบก่อนจบ handler เพื่อไม่ให้ห้องกลับมาหลัง hibernation
- ปิด handshake ของ WebSocket ให้ครบ เมื่อปิดเกมจึงไม่ทิ้ง socket ครึ่งปิด ทั้งนี้กรณีเน็ตขาดเงียบ ๆ ต้องรอเครือข่าย/server ตรวจพบการหลุดก่อน จึงไม่สามารถรับรองปิดทันทีตั้งแต่วินาทีที่เครื่องผู้เล่นขาดเน็ต
- ชุดทดสอบ backend ผ่าน 7 ชุด รวม 100 sockets, กดออก/ปิดครบทั้งห้อง, คืน slot, รหัสเก่าเข้าไม่ได้ และตรวจซ้ำหลัง hibernation

โค้ด backend: `services/cloudflare-match/` รันทดสอบด้วย `npm test` หลัง `npm ci` ส่วน `npm run dev` ใช้ identity fixture ในเครื่องเท่านั้น ไม่ใช้ Google token จริงและไม่ deploy test fixture ขึ้น production

ฝั่ง Godot เปิด `features/competition/match_service.tscn` แล้วดู child `Edge` ซึ่ง instance จาก `match_edge.tscn` มี HTTPRequest สำหรับออก session ticket ส่วน socket/RTC เป็น runtime connection ตามหน้าที่
