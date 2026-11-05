# แผน Cloud Save และการซิงก์ข้อมูลขนาดเล็ก

วันที่ 2 พฤศจิกายน 2026 · **แผนออกแบบ ยังไม่ได้เปลี่ยน protocol หรือ deploy ฐานข้อมูล**

อัปเดตตามคำสั่งผู้ใช้: **เริ่มเกมใหม่ ไม่ย้ายข้อมูลเก่า** ใช้เซฟและแคชรุ่น
`cloud_v2` แยกจากไฟล์เดิม รวมโปรไฟล์รายบัญชี สมุดปลา tutorial ห้องแข่งและ
ranking cache การรีเซ็ตเกิดครั้งเดียว; ความคืบหน้าที่เล่นหลังจากนี้ยังคงอยู่เมื่อ
เข้าเกมหรือ Google account เดิมอีกครั้ง คง session สำหรับเข้าสู่ระบบไว้
เพื่อไม่บังคับให้ล็อกอินใหม่เพียงเพราะรีเซ็ตความคืบหน้า

ตรวจ production แล้ว: ข้อมูลเก่า 18 ผู้เล่น/412 คะแนนอยู่ในตารางสำรอง
ส่วนตารางใช้งานมีบัญชี Google 2 บัญชีและคะแนน 0 รายการ ไม่ import ตารางสำรอง
เข้า Cloud Save ส่วน migrations 007–009 ทดสอบใน PostgreSQL แยกแล้ว
แต่ยังไม่ได้ deploy และ CloudSync ยังปิดอยู่ใน `online.cfg` ระหว่างพัฒนา

เป้าหมาย: ทุกเหตุการณ์สำคัญบันทึกในเครื่องก่อน แล้วส่งเฉพาะข้อมูลใหม่ไป Supabase
โดยใช้คำขอน้อย ไม่ส่งเซฟทั้งก้อนหลังจับปลา และไม่ทำให้เงิน/ไอเทม/รางวัลซ้ำเมื่อ retry
ขนาดเล็กเป็นเป้าหมายร่วมกับความถูกต้องและความเร็ว ไม่ตัดข้อมูลที่ใช้ตรวจสิทธิ์หรือกู้คืน

## สถานะที่ใช้ประกอบแผน

- ตัวเกมมี profile, สมุดปลา, สถิติสะสม, ภารกิจ, จุดโปรด/โน้ต, คลังอุปกรณ์,
  เงิน/เพชร, ปลาที่เก็บในกล่อง, สายสำรอง และ pond snapshots อยู่ในเครื่อง
- Supabase ranking เดิมรับเฉพาะ best catches ไม่ใช่ประวัติปลาทั้งหมดหรือ Cloud Save
- มี AccountAuth/Google Login และ Competition ในซอร์สแล้ว เอกสาร `google-login.md`
  ระบุว่ายังรอ Google provider และ migrations 003–006 บน production
  **ห้ามถือว่า OAuth/reset เปิดใช้แล้วจากการมีไฟล์ใน repository**
- แผนนี้ต่อยอดบัญชี Google ที่เตรียมไว้ ไม่เพิ่ม anonymous-account flow อีกชุด
  ไม่รัน reset script ไม่เปลี่ยน guest policy และไม่ย้ายเซฟเดิมเข้า Google account เอง
- บริการ RankingOnline ส่ง best statistics หลังบันทึกปลาอยู่แล้ว ต้องพัฒนาเป็น
  uploader ร่วมกับ CloudSync ไม่เพิ่ม uploader อีกตัวที่ส่งปลาเดียวกันซ้ำ

## 1. ขอบเขตและผู้มีอำนาจตัดสินข้อมูล

| กลุ่มข้อมูล | สิ่งที่ส่ง | ข้อกำหนด |
|---|---|---|
| สมุดปลา/สถิติ/อันดับ | เหตุการณ์จับปลาใหม่ครั้งเดียว | server สรุป count/total/best และอันดับจาก event เดียว |
| ประวัติ/ปลาบนแผนที่ | ID ปลา น้ำหนัก เวลา อุปกรณ์อ้างอิง และพิกัดเมื่อมี | โหลดเป็นหน้า; ไม่ส่งซ้ำในสมุดปลาและอันดับ |
| จุดโปรด/โน้ต | เฉพาะจุดหรือข้อความที่แก้/ลบ | ข้อมูลส่วนตัว, per-item revision และ tombstone |
| อุปกรณ์ที่สวม/ค่าที่เปลี่ยน | เฉพาะช่องและ ID ใหม่ | เปลี่ยนหนึ่งช่องไม่ส่ง inventory ทั้งชุด |
| ภารกิจ | event ที่เกี่ยวข้อง และคำสั่งรับรางวัล | server คำนวณความคืบหน้า/สิทธิ์รับ; ไม่เชื่อค่า claimed จาก client |
| เงิน/เพชร/คลัง/ซื้อขาย | คำสั่งซื้อ ขาย หรือรับรางวัล | server คิดราคา/ยอดคงเหลือและทำ ledger ใน transaction |
| เติมเงิน/โฆษณา | provider receipt/reference ที่จำเป็น | server ตรวจ provider และป้องกัน receipt ซ้ำก่อนให้รางวัล |
| ร้านค้า/กิจกรรม/ค่าปรับสมดุล | โหลดเวอร์ชันใหม่และ delta | มี bundled defaults, validation และขอบเขตเวอร์ชันเกม |
| pond populations | ยังไม่ส่งในเส้นทางจับปลา | หากต้องการย้ายสถานะประชากรข้ามเครื่อง ให้ออกแบบ checkpoint แยก |
| เสียง/กราฟิก/ตำแหน่งชั่วขณะ | อยู่ในเครื่อง | ไม่เขียน DB ทุกเฟรม; session presence/pose เป็น traffic อีกกลุ่ม |

การบันทึก catch event ไม่ได้พิสูจน์ว่าจับปลาจริง ผู้เล่นยังควบคุมเกมในเครื่อง
การกัน event ซ้ำช่วยความถูกต้อง ไม่เท่ากับระบบป้องกันโกงฝั่งเซิร์ฟเวอร์
ผลแข่งขัน/ภารกิจรางวัลสูงต้องมี validation ตาม session และกติกาที่ server เชื่อถือ

## 2. วิธีลดขนาดที่ทำก่อน

1. **ส่งเฉพาะส่วนที่เปลี่ยน** ไม่ส่ง profile ทั้งก้อน ไม่ส่งค่าที่ server คำนวณจาก event ได้
2. **หนึ่ง event ใช้หลายระบบ** catch เดียวอัปเดตสมุดปลา สถิติ ภารกิจ อันดับ
   และคะแนนแมตช์เมื่อมีสิทธิ์ ไม่เรียก 4–5 API แยกกัน
3. **ใช้ numeric catalog IDs** สำหรับ map/species/equipment/mission แทน string ยาว
   dictionary เป็น append-only, ID เก่าไม่เปลี่ยน/ไม่ใช้ซ้ำ และไม่สร้างจาก index ที่ sort ใหม่
4. **ไม่ส่งชื่อและคำอธิบายซ้ำ** ชื่อปลา/อุปกรณ์/แผนที่อ้าง catalog revision
   สภาพอุปกรณ์ที่จำเป็นอ้าง loadout context ที่ส่งเมื่อเปลี่ยนเท่านั้น
5. **ใช้หน่วยจำนวนเต็ม** น้ำหนักเป็นกรัม, ความลึก/พิกัดเป็นเซนติเมตร, เวลาเป็นมิลลิวินาที
   ไม่ลดความละเอียด tie-break เวลาในอันดับโดยไม่จำเป็น
6. **ส่งข้อมูลร่วมครั้งเดียวต่อ packet** protocol version, catalog version, device ID,
   base time, server revision และ match/context ID เมื่อมี ส่วนแต่ละแถวมีเฉพาะ delta
7. **ตอบเฉพาะ acknowledgement และสิ่งที่เปลี่ยน** catch ปกติไม่ส่ง Top10 กลับทุกครั้ง
   HUD รับแค่ map leader หากเวอร์ชันเปลี่ยน; หน้า Ranking ค่อยขอ Top10/50/100
8. **ไม่ลดความปลอดภัยเพื่อประหยัดไบต์** JWT/refresh token ไม่ถูกตัดสั้น
   ใช้ Authorization header; ไม่ส่ง user email, guest secret หรือ player ID ซ้ำเมื่อ auth.uid ระบุได้

เริ่มด้วย compact JSON ผ่าน RPC เพื่อใช้เส้นทาง PostgREST ที่มีอยู่
ไม่เพิ่ม MessagePack/Protobuf + Edge Function เพียงเพื่อประหยัดไม่กี่สิบไบต์
ถ้าผลวัดภายหลังชี้ว่าคุ้ม จึงทดลอง binary/compression เป็นงานแยกและเทียบ end-to-end

## 3. สัญญา protocol v2 ที่เสนอ

ตัวอย่างนี้เป็น **แบบร่าง** ID ตัวเลขยังไม่ใช่ production registry
ใช้ API ใหม่ขนานกับ ranking v1 ไม่เปลี่ยนความหมาย array เดิมทันที

```json
{"p":{"v":2,"c":1,"r":20,"d":"0123456789abcdef","t":1793612000123,"f":[[41,1,80,1250,0,150,1,3,"fish-001",0,[-1025,2050,-1250,2275,0]]]}}
```

| Header | ความหมาย |
|---|---|
| `v` | protocol version |
| `c` | immutable catalog version |
| `r` | server revision ที่ client รับและบันทึกล่าสุด |
| `d` | device-instance ID ที่สุ่มและบันทึกอย่างถาวร |
| `t` | base Unix time เป็น milliseconds ของ packet |
| `f` | catch-event tuples |
| `o` | command tuples เช่นซื้อ/ขาย/รับรางวัล มี opcode แยกจาก catch |
| `g` | loadout/context definitions ที่เปลี่ยน ไม่ส่งเมื่อ server รู้ revision นั้นแล้ว |

Catch tuple:

```text
[device_seq, map_id, species_id, weight_g, time_delta_ms, depth_cm,
 bait_id, loadout_rev, stable_fish_key, flags, optional_location]
```

`optional_location` = `[angler_x_cm,angler_z_cm,bite_x_cm,bite_z_cm,from_boat]`
ละสมาชิกท้ายเมื่อไม่มี location; ไม่ละค่าที่จำเป็นต่อ mission/journal
`stable_fish_key` ต้องคงเดิมตอนปล่อยแล้วจับซ้ำ รวม map/population generation
เท่าที่จำเป็นเพื่อไม่ชนกัน ห้ามแทนด้วย sequence ของการจับ เพราะภารกิจเดิมกันนับปลาเดิมซ้ำ
คีย์ตัวอย่างสั้นกว่าบางคีย์จริง จึงไม่ใช้ตัวอย่างนี้รับรองขนาด catch ทุกชนิด

`flags` เป็นข้อมูลช่วย decode ไม่ใช่สิทธิ์ให้รางวัล client ไม่สามารถตั้ง flag
เพื่อบังคับให้เป็น boss/mission-eligible ได้ กติกานั้นต้องตรวจจากข้อมูลที่ server ยอมรับ
ตัวเลข wire จำกัดช่วงที่ปลอดภัยกับ JSON consumers (ไม่เกิน 2^53−1)
และตรวจชนิด/ขอบเขตฝั่ง server ทุกครั้ง เวลาเครื่องไม่ใช้ตัดสินสิทธิ์ซื้อหรือช่วงกิจกรรม

ตัวอย่างตอบกลับ:

```json
[2,21,41]
```

หมายถึง `[protocol,server_revision,contiguous_ack_seq]` เมื่อมี delta เช่น leader,
wallet/inventory หรือ mission เพิ่ม domain tag และ tuple เฉพาะรายการที่เปลี่ยน
ถ้าไม่มี event และข้อมูลไม่เปลี่ยน ใช้ `[2,21]` ไม่ส่ง view เต็ม

ตัวอย่าง buy command:

```json
{"p":{"v":2,"r":20,"d":"0123456789abcdef","o":[[41,2,7,1,8]]}}
```

แถว command = `[seq,opcode,item_id,quantity,shop_revision]`
ไม่ส่งยอดเงินปลายทางหรือราคาให้ server เชื่อ ค่า opcode และรูปแบบแต่ละชนิดต้องมี schema
รับ f/o แล้วประมวลผลตาม seq ไม่ใช่แยก catch ทั้งหมดก่อน command จนลำดับซื้อขายผิด
หาก loadout/context หรือ catalog ยังไม่รู้จัก ให้ส่ง error ที่ระบุ version/context
และคง event ใน outbox จนแก้ครบ ห้ามเดา mapping เงียบ ๆ

## 4. ผลวัดขนาดเบื้องต้น

วัดด้วย `tools/measure_cloud_payloads.py` จาก fixture จำลองตามฟิลด์ใน
`CatchSettlement.make_record` และ profile schema ไม่มีข้อมูลผู้เล่นจริงหรือ HTTP
ผลเต็มอยู่ใน `cloud-payload-measurements.json`

| ตัวอย่าง | UTF-8 JSON body |
|---|---:|
| Catch object พร้อมชื่ออุปกรณ์และ location | 465 bytes |
| Best-only catch tuple ของระบบปัจจุบัน | 74 bytes |
| Request ranking แบบ guest ปัจจุบัน | 300 bytes |
| Tuple ใหม่พร้อม location | 63 bytes |
| Tuple ใหม่ไม่มี location | 37 bytes |
| RPC ใหม่หนึ่ง catch พร้อม header ของ packet | 137 bytes |
| Catch objects 10 รายการ | 4,670 bytes |
| RPC ใหม่ 10 catches พร้อม header รวม | 740 bytes |
| Version-only check | 20 bytes |
| Compact acknowledgement | 9 bytes |
| Unchanged reply | 6 bytes |
| Buy command พร้อม envelope | 62 bytes |

Catch tuple พร้อม location ลดจาก fixture object ประมาณ **86%** โดยตัดชื่อ/ข้อมูลซ้ำ
และอ้าง context ที่รู้จักแล้ว ไม่ได้แปลว่า traffic จริงหรือเวลาโหลดลดลง 86%
ระบบ ranking ปัจจุบันส่งข้อมูลน้อยกว่า Cloud Save จึงห้ามใช้ 74 หรือ 300 bytes
เป็น baseline ว่า payload ใหม่จะเล็กกว่าในทุกกรณี และ packet ที่มี context ใหม่จะใหญ่ขึ้น
ตัวอย่างไม่มี JWT/HTTP headers, TLS, TCP, compression หรือ response size
สำหรับคำขอเล็ก overhead/RTT อาจมีผลมากกว่าขนาด body จึงวัดทั้งสองอย่างก่อนตัดสิน

## 5. ตารางและความถูกต้องของการซิงก์

โครงสร้างที่เสนอ (ยังไม่สร้าง):

- `sync_devices`: account/device, contiguous sequence watermark และเวลาล่าสุด
- `sync_events`: unique `(auth_id,device_id,seq)`, payload fingerprint, status/revision
- `player_catch_events`, `player_fish_stats`, `player_best_catches`
- `player_inventory`, `player_loadouts`, `player_mission_progress`
- `player_spots`, `player_notes`: per-item revision และ tombstone
- `wallet_ledger`, `reward_claims`, `verified_receipts`: durable unique operation keys
- `save_checkpoints`: versioned manifest/pages สำหรับการกู้คืน ไม่ใช่ blob ที่ client เขียนทับ ledger ได้
- catalog/remote-config revisions แยกจากข้อมูลผู้เล่น

ใช้ Auth ownership/RLS และ RPC จำกัดขนาดโดยไม่ให้ client เขียนตารางเงินเอง
หนึ่ง transaction ตรวจสิทธิ์ ตรวจ event ซ้ำ ใช้กติกา อัปเดต domains ที่เกี่ยวข้อง
เพิ่ม revision แล้วตอบ ack หลัง commit ห้ามส่งแต่ละ domain แบบ partial แล้วเรียกว่าสำเร็จ

ลำดับฝั่งเครื่อง:

1. บันทึก catch และ outbox/sequence ใน durable transaction/file state เดียวกัน
   crash ระหว่างสองส่วนต้อง replay เติม outbox ได้จาก catch journal
2. ส่ง event ตาม seq มีได้หนึ่ง in-flight mutation batch ต่อ account/device
3. timeout ให้ส่ง seq เดิม ไม่สร้าง catch ID/ซื้อซ้ำใหม่
4. server ตอบ contiguous ack; ถ้าขาด seq ให้แจ้งช่องว่าง ไม่ ack ข้ามรายการที่ยังไม่รับ
5. บันทึก ack และ server delta ลงเครื่องอย่างทนทานก่อนล้าง outbox
6. ถ้าแอปตายหลัง server commit ก่อนรับ ack การ retry ต้องคืนผลเดิมโดยไม่เพิ่มของซ้ำ

**Outbox ใหม่ต้องเก็บทุก event ที่ยังไม่ ack** ไม่ใช้แค่ `history.map_bests`
หรือ journal ที่ถูก compact เหลือสิบตัวต่อชนิดแบบ ranking ปัจจุบัน มิฉะนั้นปลาตัวเล็ก
หรือ catch เก่าจะหายจาก Cloud Save ระหว่างออฟไลน์ เก็บเป็น durable event pages
ที่อ่านเข้า memory ทีละ batch; compact/ลบหน้าได้หลัง durable ack เท่านั้น
กำหนด storage budget/backpressure และแจ้งปัญหาดิสก์ชัดเจน ห้ามทิ้ง pending events เงียบ ๆ

คำสั่งที่ server ปฏิเสธอย่างถาวร เช่นยอดเงินไม่พอ ต้องเก็บผล rejection ที่เรียกซ้ำได้
และแจ้งสถานะ terminal ให้ client รับทราบ แยกจากสำเร็จและจาก missing-context ที่ retry ได้
การขยับ sequence watermark ต้องไม่ทำให้ client เข้าใจว่าของถูกซื้อทั้งที่คำสั่งถูกปฏิเสธ

เมื่อ compact event history ต้องเก็บ device watermark/idempotency state ต่อ
เพื่อไม่ให้ replay event เก่าหลังหมด retention ได้เครดิตอีก และ wallet/receipt ledger
ใช้ retention ของตนเอง ไม่ลบทิ้งตามประวัติปลาทั่วไป
ห้ามใช้ last-write-wins กับจำนวนเงินหรือ inventory
จุดโปรด/โน้ตใช้ per-item conflict policy; ของลบมี tombstone เพื่อไม่ให้เครื่องเก่าชุบกลับ

Cloud Save ย้ายเครื่องต้องโหลด checkpoint revision ที่สอดคล้องกันทุกหน้า
แล้วรับ events/delta หลัง revision นั้น ไม่โหลดแต่ละหน้าแบบ live จนเงิน/ของคนละ revision
checkpoint ไม่เก็บ access/refresh token และต้องมี schema/content compatibility กับเกมรุ่นเก่า

## 6. ความถี่และงบ payload ที่เสนอ

| เหตุการณ์ | จังหวะส่ง |
|---|---|
| จับปลา | เข้าคิวทันทีหลัง local commit รวม facts + leader version ใน RPC เดียว |
| มี catch ใหม่ระหว่าง request | ต่อคิว batch ถัดไป ไม่เปิด parallel mutations |
| Offline backlog | สูงสุด 64 events หรือ 16 KiB ต่อ batch แล้วแต่ถึงก่อน |
| ซื้อ/ขาย/claim | คำสั่งทันที; รอผลยืนยันของ server ไม่เขียนยอดปลายทางเอง |
| แก้โน้ต/จุดโปรด/สวมอุปกรณ์ | รวมรายการของ item/slot เดียวกันหลังหยุดแก้ประมาณ 0.5–1 วินาที |
| เปลี่ยนบัญชี/เข้าเกมใหม่ | version check แล้วขอเฉพาะ domains ที่เปลี่ยน |
| หน้า Ranking | ขอเฉพาะ Top N ที่เลือก; มี version ใช้ unchanged reply |
| HUD leader | ผนวกกับ catch response; periodic refresh เดิมเป็น fallback |
| Remote config | ตรวจ version ตอนเข้าเกม/เปลี่ยนแผนที่ ไม่ตรวจทุกเฟรม |
| Pause/background | บันทึก outbox ก่อน; ส่งเท่าที่ OS อนุญาต ไม่พึ่ง request ตอนปิดแอป |

งบเริ่มต้นสำหรับ telemetry/QA: catch ปกติ body ราว **100–250 bytes** เมื่อ
context อยู่แล้ว, ack ที่ไม่เปลี่ยน domains **ไม่เกิน 32 bytes**, domain responses
เป้าหมาย **ไม่เกิน 2 KiB** ยกเว้นประวัติ/restore ที่แบ่งหน้า
server hard cap เสนอ **32 KiB/request** พร้อมจำกัด arrays/strings และงานต่อ transaction
ตัวเลขนี้เป็นเป้าหมายทดสอบ ไม่ใช่ผล benchmark latency หรือ worst-case promise
ข้อความภาษาไทยวัดเป็น UTF-8 bytes เพิ่มจากขีดจำกัดจำนวนตัวอักษร
batch ที่ใหญ่เกินต้องแบ่ง; ห้ามตัด event/ข้อความเงียบ ๆ

ใช้ compact JSON ก่อน; compression สำหรับข้อมูลก้อนใหญ่พิจารณาหลังวัดและยืนยันว่า
gateway/client รองรับจริง หลีกเลี่ยง base64 สำหรับ JSON ปกติเพราะเพิ่มขนาด
Realtime ถ้าจะใช้ให้เป็น notification ว่า version เปลี่ยนหรือ compact public leader
ห้าม broadcast private save/wallet ทุกแถวให้ทุกคนและอย่า subscribe ซ้ำกับ poll ที่ถี่เท่าเดิม
รับ reconnect แล้วต้อง version-check เพื่อชดเชย notification ที่หาย

## 7. ลำดับดำเนินการและเกณฑ์ผ่าน

| ระยะ | งาน | เกณฑ์ก่อนขึ้นระยะถัดไป |
|---|---|---|
| 0 | ตรวจสถานะ Google Auth/production schema และสรุป reset/import policy ตามงานที่อนุมัติไว้ | ไม่ deploy/reset จากข้อสันนิษฐาน; ทดสอบ account isolation |
| 1 | freeze v2 schemas + numeric registries + encoder/decoder + byte benchmarks | round-trip ข้อมูลครบ, ปฏิเสธ version/ID ไม่รู้จัก, bounds/fuzz/Thai/precision ผ่าน |
| 2 | RPC ใหม่และ durable outbox + dedup/ack/revision | fault injection ทุก crash boundary, retry ซ้ำ, seq gap, concurrent devices และ auth expiry ผ่าน |
| 3 | Catch ingest รวมสมุดปลา/ประวัติ/สถิติ/อันดับ + private spots/notes | client ส่งเหตุการณ์เดียว, ห้ามนับปลาเดิมซ้ำใน mission, leader ไม่ดึง Top10 เกินจำเป็น |
| 4 | Cloud checkpoints + restore + loadout/mission synchronization | แบ่งหน้า/ข้ามเครื่อง/ลบข้อมูล/tombstone/อัปเกรด schema ไม่ทำ progress หาย |
| 5 | wallet/inventory/mission rewards และ provider receipts | server transaction, price/catalog check, double-spend/double-claim และ receipt replay ผ่าน |
| 6 | ร้านค้า กิจกรรม balance config และ optional Realtime invalidation | มี offline defaults, rollback version, content compatibility และขีดจำกัด traffic |

ก่อนระยะ 5 ต้องกำหนดนโยบาย offline economy ให้ชัด: แนะนำ premium currency,
การเติมเงินและรางวัลมูลค่าสูงยืนยันออนไลน์ ส่วนรายได้จากการเล่นออฟไลน์เป็น provisional
จนผ่านกติกาซิงก์ การสำรองยอดเงินเดิมไม่ได้ทำให้ยอดนั้นน่าเชื่อถือขึ้น
ห้ามให้ client balance overwrite ยอดที่ตรวจสอบแล้วบน server

วัดจริงบน Android/Wi-Fi/เครือข่ายมือถือ: request/response body และ headers,
จำนวน requests ต่อ catch, p50/p95 end-to-end, queue lag, server query time และ egress
เทียบ fixture 1/10/64 events, 1/10/50 clients, offline replay, ชื่อ/โน้ตไทย,
match-active vs normal และมี/ไม่มี context ใน cache
อย่าสรุปว่าขนาดเล็กเท่ากับความเร็วดีขึ้นจนผ่าน latency/load test

Rollout เป็น API/feature flag ใหม่ ทดสอบ staging ก่อน ไม่ลบ ranking v1 หรือเปลี่ยน
Apps Script compatibility bridge เอง ให้มี rollback ฝั่ง client/server และข้อมูลคงรูป
ตาม Google-login/legacy policy ที่ตัดสินแล้ว การกลับ binary เก่าไม่ย้อน ledger ใหม่
ตัว protocol/outbox ต้องหยุดส่งเมื่อเปลี่ยนบัญชีและห้ามนำ pending events ไปลงอีกบัญชี

## เอกสารอ้างอิง

- [Supabase Database Functions/RPC](https://supabase.com/docs/guides/database/functions)
- [Supabase JSON/JSONB](https://supabase.com/docs/guides/database/json)
- [Supabase Broadcast](https://supabase.com/docs/guides/realtime/broadcast)
- ซอร์สปัจจุบัน: `ProfileStore`, `CatchArchive`, `CatchSettlement`, `MissionProgress`,
  `FishingJournal`, `AccountAuth`, `Competition` และ service migrations ที่มีอยู่
