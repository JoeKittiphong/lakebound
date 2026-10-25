# แผน refactor Lakebound รอบถัดไป

วันที่ประเมิน: 25 ตุลาคม 2026 · baseline ปัจจุบัน: 0.1.12

เริ่มทำ phase 0–1 แล้ว: baseline/test inventory และ Session/HUD APIs พร้อม
aggregate modal ownership ดู [ผลตรวจ phase 1](refactor-phase1-verification.md)
ส่วน phase 2–6 ยังเป็นแผน ไม่ได้เปลี่ยนกติกาเกมหรือ schema เซฟในรอบแรก
`refactor_plan.md` และ `architecture.md` เป็นประวัติรอบก่อน บางขอบเขตในเอกสารเดิม
แยกไปแล้ว เช่น FightSimulation และ CollectionStore จึงไม่ควรทำซ้ำ

## เป้าหมายและสิ่งที่ต้องคงเดิม

ให้เพิ่มแผนที่ ปลา อุปกรณ์ และ UI ได้โดยไม่ต้องแก้ session/เซฟ/การต่อสู้พร้อมกัน
คงฉาก `.tscn` ที่แก้ก่อน Play ได้ ใช้ Resource สำหรับ tuning และข้อมูลชนิดต่าง ๆ
ไม่ย้าย layout ไปสร้างด้วยสคริปต์ และไม่เพิ่ม global event bus/Autoload สำหรับ session

ต้องคง save schema/path และ reset generation เดิม, species IDs, region/map IDs,
mission progress, catch event IDs, ปลาในบ่อเดิม, เหรียญ/เหยื่อ/เอ็น/กล่องปลา และ
resource UIDs ห้ามใช้การ reset ผู้เล่นเพื่อแก้ migration
คง enum ordering และผลตัวเลขของระบบสู้ปลา รวมถึงการรับแรงตาม kgf ของเอ็น
แยกการเปลี่ยนสมดุลเกมออกจาก PR refactor

## สิ่งที่พบจากซอร์สปัจจุบัน

| จุด | หลักฐานและผลกระทบ | แนวทาง |
|---|---|---|
| Session รู้ภายใน HUD มากเกินไป | `gameplay.gd` ประมาณ 261 บรรทัด มี `get_node()` 25 จุด รวม path ลึกของแผงอุปกรณ์ ภารกิจ tutorial และ depth | ให้ HUD/แผงเป็นเจ้าของ nodes และเปิด API ตามความสามารถ |
| การจับปลา/เซฟข้ามหลายเจ้าของ | session สร้าง `catch_record` และบันทึก profile + collection; controller retry/keep/release และเก็บ population; collection มี store แยก | รวม workflow ใน CatchSettlement โดยคง façade และ idempotency |
| Profile รวมหลาย domain | `angler_profile.gd` ประมาณ 299 บรรทัด รวม IO/validation, stock, อุปกรณ์, line recovery, กล่องปลา, journal, missions | แยก store และกฎ pure ทีละส่วน ไม่เปลี่ยน schema พร้อมกัน |
| HUD รวมหลายความรับผิดชอบ | `fishing_hud.gd` ประมาณ 365 บรรทัด มี state display, gesture, cast reason, fish box, ecology และ mission presentation | แตก presenter/scene เฉพาะส่วนที่มี lifecycle ของตนเอง |
| Controller รวม cast/lure/fight/settlement | `fishing_controller.gd` ประมาณ 410 บรรทัด แม้ตัวเลขต่อสู้อยู่ FightSimulation แล้ว | แยก policy/preflight และ lure behavior หลังจัด ownership ผลจับปลา |
| ข้อมูล region ซ้ำกับของจริง | `RegionCatalog.MAPS` มี scene path และ fish_count/mission_count เป็นค่าตายตัว ขณะที่ roster/mission อยู่คนละ resource | ให้ RegionDefinition เป็น source เดียวและคำนวณจำนวนจาก catalog |
| เอกสารกับ test runner ตาม feature ไม่ทัน | runner ยังไม่ลงทะเบียน suites ใหม่บางตัว เช่น regions/encyclopedia/loading_flow และ architecture เก่ายังบอก session ไม่เจาะ HUD | ทำ baseline matrix และอัปเดตตาม implementation จริง |
| ความเสี่ยง export dependency | เคยตัด SVG ที่ HUD ใช้จน startup ล้มเหลว; การรัน source อย่างเดียวจับไม่เจอ | เพิ่ม exact-export startup/dependency gate แยกจาก source tests |

จำนวนบรรทัดใช้ช่วยระบุตำแหน่ง ไม่ใช่เหตุผลให้แตกทุกฟังก์ชันเป็นคลาส

## โครงสร้างความรับผิดชอบเป้าหมาย

```text
GameplaySession (Node ใน gameplay.tscn)
 ├─ InputRouter: รวม keyboard/touch และลำดับ traversal/fishing/camera
 ├─ ModalCoordinator: pause/input focus และการคืนสถานะหลังปิดแผง
 ├─ CatchSettlement: landed → record → keep/release → persist
 ├─ Player / Boat / CameraRig / Ecosystem: scene peers ที่มี API ของตนเอง
 ├─ FishingController: state machine และคำสั่งผู้เล่น
 │   ├─ CastPolicy (pure preflight result)
 │   ├─ FightSimulation (pure numeric state; มีอยู่แล้ว)
 │   └─ LureMotion (pure behavior เมื่อแยกแล้วมีประโยชน์)
 └─ FishingHUD: ต่อ presenter และ emit user intent
     ├─ FishBox scene + presenter
     ├─ Fight readout / cast feedback
     └─ Tackle / Missions / Collection / Result scenes

AnglerSave Autoload façade (คง API ผู้ใช้เดิมระหว่าง migration)
 ├─ ProfileStore: load/validate/migrate/atomic write
 └─ domain rules: inventory/equipment, storage, missions
FishCollection façade → CollectionStore (มีอยู่แล้ว)
RegionDefinition resources → world/roster/mission catalog
```

นี่คือทิศทางของ boundaries ไม่ใช่คำสั่งสร้างคลาสทั้งหมดทันที Pure policy ใช้
RefCounted/plain data; ส่วนที่ต้องมี lifecycle หรือ Inspector ใช้ node/scene

## ลำดับงานเป็น PR ขนาดตรวจทานได้

| ลำดับ | ขอบเขต | เกณฑ์เสร็จ |
|---|---|---|
| 0 · baseline และ test inventory | ลงทะเบียน suites ปัจจุบันใน runner, แยก headless/render/packed/device, จัด fixture save แยกทุก suite, บันทึก failure เดิมตาม revision | รันจาก clone ใหม่ได้ มี log/ผลจริง; assertion ที่ผิดเพราะ fixture ต้องแก้ตามสาเหตุ ไม่ลดเกณฑ์เพื่อให้เขียว |
| 1 · HUD API และ modal ownership | เพิ่ม `bind_session`, `set_depth_limit`, `is_tutorial_active`, `open_tackle`, `show_boss_notice` หรือ API ชื่อเหมาะสม; panel emits open/close; แทน path ลึกใน session ทีละจุด | gameplay ไม่เข้าถึง internals ของ HUD; เปิดหลายแผง/back/focus/กลับเมนูคืน pause และ touch ownership ถูกต้อง |
| 2 · persistence และ catch settlement | แยก ProfileStore ก่อน แล้ว CatchSettlement ที่รับ immutable catch event; façade เดิม delegate | save เก่าโหลดได้; event ซ้ำไม่เพิ่มปลา/เงิน/ภารกิจ; write ล้มเหลว retry ได้; keep/release ไม่สูญปลาและไม่บันทึกซ้ำ |
| 3 · input และ session orchestration | แยก input routing/modal coordination เป็น child nodes ที่ session ต่อ reference; คงลำดับ process/physics | multitouch, aim release, fishing, swim/jump, boat drive/fish/exit, camera และ back/focus ผ่านทั้งจอปกติ/กว้าง |
| 4 · presentation เป็นส่วนย่อย | FishBox presenter ฟัง `profile.changed`, mission tracker ฟัง progress; cast reason เปลี่ยนตาม preflight/state; อ่านต่อเฟรมเฉพาะค่าต่อเนื่อง | จำนวน/น้ำหนักกล่องเปลี่ยนทันทีเมื่อ keep/sell; state เตือนถูกต้อง; HUD ไม่มีงานอ่านบันทึกทั้งก้อนทุกเฟรม |
| 5 · region/config และ policy | ทำ RegionDefinition, คำนวณ counts, shared lookup; CastPolicy คืน reason code + data และ presenter แปลเป็นข้อความ; พิจารณาแยก lure movement | ทั้ง 6 map ใช้ roster/mission ที่ตรงกัน; save key เดิม; ปลาเลือกเหยื่อ/ความลึกตามเดิม; region unknown ไม่เขียนทับข้อมูลเดิม |
| 6 · export/cleanup | ตรวจ resource graph ของ artifact จริง, packed loading/menu/เข้าออกแต่ละ region; ลด legacy fixtures เมื่อ coverage ทดแทนครบ; อัปเดต docs | clean-clone import และ signed Android artifact ที่ตรง version ผ่าน; ไม่มี missing dependency/secret/test asset ใน release |

เริ่มที่ PR 0 และ PR 1 ก่อน ผลคุ้มค่าคือจับ regression ได้เร็วและลดการแก้ path
ข้ามฉาก ส่วน PR 2 ให้ทำแยกและละเอียดที่สุดเพราะเกี่ยวกับข้อมูลผู้เล่น

## เงื่อนไขทดสอบสำคัญ

- **สู้ปลา:** กลับจากแดงเข้าเหลืองได้, เวลา/ผลไม่เปลี่ยนที่ 30/60/120 Hz,
  surge และสุดรอกไม่บังคับแดงทุกเฟรม, เอ็น 80 kgf กับปลา 2 กก. ไม่ขาดเพราะสี UI,
  เอ็นอ่อนขาดเมื่อ force เกิน rating ตาม grace จริง
- **จับ/เซฟ:** landed event เดียว, duplicate callback, quit/reopen ระหว่าง result,
  disk write failure/rollback/retry, schema ใหม่กว่าที่รองรับ, legacy river save
- **กล่อง/อุปกรณ์:** empty/near-full/full, ปลาที่หนักเกินที่ว่าง, keep/release/sell,
  bait depletion, สายหมด/สั้น, lure recovery, ซื้อ/เปลี่ยนอุปกรณ์
- **ฉากและ input:** authored hierarchy/Inspector ยังใช้ได้, modal ทับกัน,
  focus loss, touch cancel, สองนิ้ว, คืนจากเรือ/ว่ายน้ำ, Android back/safe area
- **content/pack:** ปลา 105 รายการและ roster ของ 6 map ตาม catalog ปัจจุบัน,
  region enter/back, loading cinematic, resource paths/UID/remaps ในแพ็กจริง

ใช้ tests ที่มีอยู่ก่อน เช่น `fishing_recovery`, `mobile_multitouch`, `economy`,
`missions`, `boat_integration`, `regions_*`, `fish_encyclopedia`, `loading_flow`,
`refactor_boundaries` และเพิ่มเฉพาะ failure mode ที่ coverage ยังไม่ถึง
อย่าถือว่า legacy suite 16 species ครอบคลุม encyclopedia ทั้งหมด

การเขียนสองไฟล์เซฟคนละ store ไม่ใช่ transaction เดียวโดยอัตโนมัติ: PR 2 ต้อง
กำหนดการกู้คืนหลัง crash ให้ชัด เช่น event ID ที่ replay แล้ว idempotent ก่อนอ้าง
ว่า catch settlement มี atomicity ข้าม profile/collection

## วิธีส่งและย้อนกลับ

แต่ละ PR ต้องระบุ behavior เดิมที่คงไว้, public API ที่เปลี่ยน และชุดทดสอบที่รัน
แยก extraction, การลบ compatibility façade และการเปลี่ยนสมดุลคนละ PR
ทำ additive migration หากจำเป็นและเก็บ fixtures เดิมไว้ ห้าม rename resource/UID
พร้อมเปลี่ยน logic โดยไม่มีเหตุผล การ rollback โค้ดต้องยังอ่าน save ที่ผลิตโดย PR
นั้นได้ หรือมี migration rollback ที่ทดสอบแล้ว ก่อนเปิดให้ผู้เล่นใช้งาน

## สถานะ

phase 0–1 ลงมือแล้วตามผลตรวจที่ลิงก์ด้านบน งานนำขึ้น GitHub รอบก่อนแยกจาก
refactor นี้ ยังไม่ได้เพิ่ม CI release ที่เข้าถึงคีย์ลงนาม หรือเริ่มย้าย persistence
การทำ build/import บนเครื่องสะอาดยังต้องมี Godot 4.7.2 และ
Android toolchain สำหรับขั้น Android ตาม README
