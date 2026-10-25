# Persistence refactor และ performance — phase 2

25 ตุลาคม 2026 · ต่อจาก `1ec2af8` · งานรอบนี้เก็บ local ตามคำขอ ยังไม่ push
หรืออัปเดต draft PR #1 เดิม

## Ownership

- `ProfileStore` เป็น RefCounted/static IO, validation และ additive migration
  ของ ConfigFile v1; `AnglerProfile`/AnglerSave ยังเป็น façade และเจ้าของกฎ
  inventory/equipment/coins/missions รวมถึง rollback เมื่อ commit ไม่สำเร็จ
- `CatchSettlement` สร้าง record ครั้งเดียวจาก landed fish, บันทึก journal และ
  ส่ง event เดิมไปสมุดปลา รวมการ reconcile เมื่อเปิด session
- `FishingController` ยังเป็นเจ้าของ state และการ keep/release ในโลก และจะไม่
  ทิ้ง RESULT/โอนปลาเข้ากล่องจนกว่าจะบันทึก landed event สำเร็จ
- `FishBoxView` เป็น script ของฉากกล่องปลาที่มี hierarchy เดิม ใช้ cached node
  references และ `profile.changed` เพื่อ invalidate; HUD ไม่วนรวม weight ทุกเฟรม

ไม่มี Autoload ใหม่ ไม่เปลี่ยน path/reset generation, region/species IDs,
กฎแรงดึงเอ็นหรือ FightSimulation และไม่เพิ่มบริการภายนอก

## การบันทึกและกู้คืน

สองไฟล์ **ไม่ใช่ transaction เดียว**: profile journal เป็นแหล่ง event ที่ durable
แล้ว collection บันทึกสถิติพร้อม applied event IDs ในไฟล์เดียวกันผ่าน `.tmp`/rename
หากแอปหยุดระหว่างสอง write การเปิด session ครั้งต่อไป replay event ที่ยังไม่ลง
collection; ID เดิมไม่เพิ่ม journal/สถิติ/mission reward ซ้ำ

Collection ยังคง `meta.version=1` และ section `fish` เดิม เพิ่ม metadata แบบ additive:
`catch_events_initialized` และ `catch_events` (ID → outcome flags ขนาดเล็ก)

- Collection v1 ที่มีอยู่: seed ID ของ journal เก่าโดยไม่เพิ่มสถิติซ้ำ เนื่องจาก
  ไม่มีข้อมูลในไฟล์เดิมพอจะแยกว่าจับตัวใดถูกนับแล้วบ้าง ไม่เดาย้อนเขียนทับสถิติเดิม
- Collection ที่ไฟล์หายจริง: สร้างใหม่แล้ว replay รายการที่รู้จาก journal
- Empty collection เก็บ initialized marker ได้แม้ยังไม่มี section fish จึงไม่ข้าม
  event แรกหากแอปหยุดหลังเขียน journal
- IO ล้มเหลว: เก็บ RESULT และปลาเดิมไว้ retry โดย event ID เดิม; collection ที่
  เพิ่มสถิติใน memory แล้วจะไม่บวกซ้ำเมื่อ retry และ flush เมื่อเขียนได้
- Replay หลาย event: stage ใน memory แล้วเขียน collection ครั้งเดียว ไม่ write
  ไฟล์ใหม่ต่อ event ทุกตัว
- Version ที่ไม่รองรับ, event metadata ผิดรูป หรือสถิติที่เสียในไฟล์ที่มี ledger:
  บล็อกการเขียนทับและเก็บ bytes เดิม Controller แสดงเหตุผลก่อนใช้เหยื่อหากอ่าน
  collection เดิมไม่ได้

ไม่อ้างว่าสามารถกู้ event ที่ไม่เคยเขียนถึง journal หรือแยกช่องว่างในสถิติก่อนยุค
ledger ได้แน่นอน ไม่มีการนำ profile/collection กลับไปเขียนด้วยแอปรุ่นเก่าเพื่อทดสอบ
downgrade; โค้ดเก่าอาจละทิ้ง metadata ใหม่เมื่อ save จึงไม่ควร downgrade ระหว่าง
event ที่ยังรอ reconcile การปิดแอปก่อนเลือก keep/release ไม่ได้ restore หน้าผลเดิม
แต่ปลาที่ยังไม่ได้ keep ยังคงอยู่ใน saved population ตามพฤติกรรมเดิม

## ผลวัด HUD CPU แบบจับคู่

Godot 4.7.2, Windows desktop, headless microbenchmark ของ `FishingHUD._process`
โดย freeze simulation และใช้ข้อมูลเดียวกัน ก่อนวัด warmup 100 รอบ แล้ว 5 samples
× 2,000 iterations ต่อ scenario ทำ before/after สลับกัน 3 คู่ ใช้ median ของแต่ละคู่
และ median ข้าม 3 รอบ ซอร์ส before อยู่ที่ `1ec2af8`; ทุกคู่ใช้ benchmark script เดียวกัน
โหมด `--baseline` ปิดเฉพาะ assertions ของ cache ที่ซอร์สก่อนแก้ยังไม่มี

| จำนวนปลาเก็บ | ก่อน µs/update | หลัง µs/update | ลดเวลา |
|---:|---:|---:|---:|
| 0 | 50.473 | 31.558 | 37.5% |
| 200 (stress case) | 94.629 | 30.450 | 67.8% |

การคำนวณ `box_weight()` ระหว่างข้อมูลคงเดิมลดจาก 10,000 เป็น **0 ครั้ง** ต่อ
10,000 updates; เมื่อ `profile.changed` จะ refresh หนึ่งครั้ง ไม่ทำซ้ำตลอดเฟรม
ธุรกรรม gameplay ยัง emit changed ตามเดิม Fixtures ที่เขียน dictionary โดยตรง
ต้อง emit changed ให้เหมือน transaction จริงด้วย

นี่คือเวลา CPU ของการอัปเดต HUD ไม่ใช่ frame time/FPS ของทั้งเกม และ 200 ตัวเป็น
ชุด stress ไม่ใช่ข้อกำหนดว่ากล่องทุกแบบใส่ปลาได้ 200 ตัว

## รอก 3D และ rendered frame probes

Reel viewport เคย redraw ทุกเฟรมที่มองเห็น แม้ pose ไม่เปลี่ยน ตอนนี้ใช้ภาพเดิม
และร้องขอ UPDATE_ONCE เมื่อหมุนรอก, brake slip, tilt ยังไม่หยุด, เปลี่ยน equipment,
show หรือ resize; hidden ยังคง disabled แสง โมเดลและเงาเดิมไม่ได้ถูกลดคุณภาพ
ตั้ง `continuous_rendering=true` ใน Inspector หากโมเดลในอนาคตมี AnimationPlayer
หรือ time shader ที่ขยับเองนอก pose controller

| ฉาก 1280×720, OpenGL compatibility, GTX 1660 Ti | ก่อน cache รอก | หลัง |
|---|---:|---:|
| Ready, median draw calls | 526 | 526 |
| Fight, neutral reel, median draw calls | 631 | 549 (ลด 13.0%) |
| Fight, neutral reel, median primitives | 142,438 | 111,574 |
| Fight, nodes/resources | 3,501 / 2,859 | 3,501 / 2,859 |

Probe freeze fish simulation ด้วย seed 4207, warmup 90 frames และเก็บ 120 frames
ต่อ Ready/Fight ไม่ได้ตีความ engine process monitor (~16–18 ms ในรอบเหล่านี้)
เป็น GPU time หรือยืนยัน FPS gain เมื่อหมุนรอกจริงยัง render ภาพเคลื่อนไหวตามปกติ
การทดสอบรอกแยกวัด draw calls ของ cached idle เทียบ continuous เป็น **1 กับ 83**
และตรวจ winding, slip, settled tilt, hidden/show, resize และ equipment replacement

หมายเหตุ engine: node getter ใน Godot 4.7 ยังคงคืน UPDATE_ONCE แม้ RenderingServer
ใช้คำขอนั้นไปแล้ว จึงตรวจทั้ง policy และ measured draw calls ไม่ assert ว่า node
getter ต้องกลับเป็น 0 ดู [SubViewport source](https://raw.githubusercontent.com/godotengine/godot/4.7/scene/main/viewport.cpp)
และ [update modes](https://docs.godotengine.org/en/latest/classes/class_subviewport.html)

## Verification และหลักฐาน

- `catch_settlement`: **36 checks, 0 failures** รวม duplicate, IO failure ทั้งสอง
  store, reopen/replay, legacy/future/corrupt files, missing/empty collection,
  100 events/หนึ่ง collection write และ controller Keep gate จริง
- headless รอบกว้าง: **28/29 suites ผ่าน** ข้อที่ไม่ผ่านคือ camera clearance เดิม
  ใน mobile_fishing_tuning ที่พบก่อน phase 1 ไม่มีการลด assertion เพื่อให้เขียว
- focused safety rerun: catch_settlement, refactor_boundaries, startup_flow,
  economy และ fishing_recovery ผ่านหลังการแก้ safety ล่าสุด
- rendered checks: collection, missions_visual, fishing_recovery_visual,
  fishing_visual, rod_tension, mobile_multitouch และ reel_render ผ่าน
- HUD และ frame performance probes ผ่าน พร้อม operation-count assertions
- Slow full-river walk ไม่ได้รันซ้ำรอบนี้ ข้อจำกัด timeout จาก phase 1 ยังอยู่
- ยังไม่ได้วัด Android hardware/FPS หรือสร้าง signed Android bundle ใหม่

ผล machine-readable และภาพอยู่ใน `exports/qa-refactor-phase2/`: `focused`,
`regression`, `render`, `headless-final`, `safety-final`, `performance-final`,
`reel-final`, และ paired before/after ที่ `paired/comparison.json`
Initial/debug logs เก็บไว้ด้วย ไม่ใช้ failure ของ assertion ที่อ่าน getter ผิดมาอ้าง
ว่า test ผ่าน; final reel test ตรวจ semantics ที่ถูกต้องและ draw counters จริง

## งาน performance ถัดไป

Ready ยังมี ~526 draw calls ใน renderer ที่วัด จึงควร profile terrain chunks,
props ซ้ำ/foliage batching และ shadow budgets บน Android ก่อนเลือก MultiMesh/LOD
ไม่รวม mesh ทั้งฉากจนแก้ใน Editor ไม่ได้ และไม่ลดคุณภาพ/ขนาด texture โดยไม่มีภาพ
และ device measurements รองรับ Profile ยัง serialize/deep-copy ทั้งข้อมูลต่อ
transaction ซึ่งควรวัดกับ save ขนาดใหญ่ก่อนแยก dirty domains หรือเปลี่ยน format

## งานต่อเนื่องที่ลงมือแล้ว

รวม mission tracker invalidation, indexed catalog lookup, visible-fish filtering
และ rollback snapshot สำหรับเซฟใหญ่แล้ว ดูผลและขอบเขตที่
[optimization-2026-10-25.md](optimization-2026-10-25.md).
งาน GPU/LOD/shadow budgets ยังต้องวัดบน Android จริง ไม่ใช้ผล CPU มาอ้างแทน.
