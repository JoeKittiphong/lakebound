# แผน refactor Lakebound

วันที่สำรวจ: 20 ตุลาคม 2026

สถานะดำเนินการ: ทำ refactor ตามขอบเขตระยะ 0–5 แล้ว แยกกล้อง/บ่อ/effects/result/rod control, รวม geometry และ tuning, แยก numerical fight กับ persistence, ใช้ signals สำหรับ HUD/collection และเพิ่ม test runner พร้อมเอกสาร ดูโครงสร้างจริงที่ `architecture.md` และผลทดสอบใน `../exports/qa-refactor/final/` ข้อความด้านล่างเก็บเหตุผลและแผนตั้งต้น; ยังไม่ยืนยัน Android hardware หรือ signed build ใหม่

## ข้อสรุป

โครงสร้างเดิมแบ่งตาม feature ได้ดีอยู่แล้ว ควรเก็บ `features/`, `world/`, `actors/`, `data/`, `shared/` แล้วปรับขอบเขตความรับผิดชอบและการสื่อสารระหว่างส่วน มากกว่าย้ายไฟล์ทั้งโปรเจค

เป้าหมายคือแก้ฉาก/UI ใน Editor ได้โดยไม่ต้องตามแก้ script หลายจุด เพิ่มปลาและปรับ balance ได้จาก Resource และทดสอบระบบตกปลาโดยไม่ต้องพึ่งฉาก/UI เต็มชุด ทั้งนี้ต้องรักษาพฤติกรรมการเล่นและเซฟเดิม

## โครงสร้างที่พบ

รากเกมจริงอยู่ที่ `fishing-game/` ส่วน `art/`, `retopology/`, `skills/`, `.tools/` อยู่ใน workspace ชั้นนอก ไม่รวมอยู่ในการย้าย runtime รอบนี้

```text
fishing-game/
  project.godot
  features/
    loading/                 หน้ารอโหลดและเปลี่ยนฉาก
    menu/                    เมนูเริ่มเกม
    gameplay/                ฉากรวมและตัวเชื่อมระบบ
    fishing/                 controller, HUD, effects
    collection/              สมุดสะสม, หน้ารายการ, การบันทึก
    equipment/               มีพื้นที่สำหรับอุปกรณ์อยู่แล้ว
  actors/player/             ตัวละครและการเคลื่อนที่
  world/pond/                จำลองปลา, runtime record, visual, model scenes
  data/fish/                 FishSpecies และ catalog ของ Resource
  shared/ui/                 joystick, reel, tension meter, safe area
  shared/branding/
  assets/                    โมเดล/ภาพ/เสียง/ทรัพยากร UI
  tests/                     simulation, collection, catalog, models, visual
  tools/                     เตรียม asset, capture, build, verify release
  docs/                      gameplay, controls, assets, Android, release
```

`project.godot` ระบุ Godot 4.7, Mobile renderer, Jolt และ viewport 1280×720 แบบ expand; build script ตั้ง executable เริ่มต้นเป็น 4.7.2 แต่ยังไม่ได้เรียกตรวจเวอร์ชันจริง

เส้นทางเริ่มเกมคือ `loading.tscn` → `main_menu.tscn` → `gameplay.tscn` มี Autoload `FishCollection` สำหรับข้อมูลสะสมข้ามฉาก

## หลักฐานและลำดับความสำคัญ

| ระดับ | จุดที่พบ | ผลต่อการดูแล | แนวทาง |
|---|---|---|---|
| สูง | `gameplay.gd` รวม camera gesture, follow, keyboard/touch, player state, collection และ navigation | เปลี่ยนการควบคุมหรือ UI กระทบ session | แยก camera rig; ให้ gameplay ทำ orchestration |
| สูง | gameplay เรียก `hud.get_node("SafeArea/CollectionButton")` และ `CollectionPanel`; HUD เจาะ `RodJoystick/Base`, `Knob`, `Reel` | เปลี่ยนโครงสร้างฉากลูกแล้วผู้ใช้ฉากลูกพัง | เพิ่ม public method/signal ให้เจ้าของฉากดูแลโหนดภายในเอง |
| สูง | `gameplay.tscn` รวม World, lake, dock, trees, camera และ effects | แก้สถานที่หรือใช้ effects ซ้ำลำบาก | แยก pond, camera rig และ effects เป็น scene ที่แก้ใน Editor ได้ |
| สูง | `player.gd` clamp พื้นที่เดินเอง; ecosystem มี water/dock bounds; controller รู้ geometry ท่าเรือใน `_within_landing_reach()` | รูปร่างสถานที่กับกติกาการเล่นอาจคลาดกัน | ให้ pond เป็นเจ้าของกติกาพื้นที่และ landing query |
| กลาง | HUD อ่าน state ทุกเฟรม แม้ controller มี `state_changed`; ecology นับปลาและสร้างข้อความซ้ำขณะ panel เปิด | งานแสดงผลกับ data source พัวพันกัน | ใช้ event กับข้อมูลที่เปลี่ยนเป็นครั้ง ๆ; อ่านค่าต่อเนื่องเฉพาะ meter/ระยะ |
| กลาง | gameplay เขียน `player.move_speed` เป็น 1.8/3.8 ทุกเฟรม | ค่า Inspector ถูกทับเมื่อเล่น | แยก walk/fight speed ที่ปรับจาก Inspector แล้วเปลี่ยน movement mode |
| กลาง | controller และ effects ใช้ระยะเวลาเหวี่ยง `0.6` คนละจุด | เปลี่ยนเวลาแล้วภาพกับสถานะไม่ตรงกัน | ใช้ tuning ร่วมและ normalized cast progress |
| กลาง | ใช้ `Node`, `Resource`, `RefCounted` สำหรับ interface ที่มีสมาชิกเฉพาะ | ตรวจพบชื่อสมาชิกผิดช้าและ API ไม่ชัด | เพิ่มชนิดจริงทีละขอบเขต เช่น FishState, PondEcosystem, FishingController |
| กลาง | `collection_panel.gd` คุม pause ทั้ง SceneTree และจัด row ภายในเอง; `_fit_grid()` ทุกเฟรม | UI มีอำนาจเหนือ session และผูกกับ layout ของ row | ให้ session คุม pause; row มี bind method; จัด grid เมื่อขนาด/ข้อมูลเปลี่ยน |
| กลาง | `fish_collection.gd` รวมสถิติ, persistence และข้อความภาษาไทย | ทดสอบเซฟและเปลี่ยน UI feedback แยกกันยาก | แยก store เมื่อมี regression tests รองรับ คง Autoload façade เดิม |
| ต่ำ | build script มี path เฉพาะเครื่อง; verifier อ้าง Gradle intermediate และชื่อ release คงที่ | ย้ายเครื่อง/เปลี่ยนเวอร์ชันต้องแก้หลายจุด | รับ runtime/SDK/artifact paths เป็น argument และกำหนด version source |

script หลักมีขนาดประมาณ 121–222 บรรทัด จึงไม่จำเป็นต้องแตกทุกฟังก์ชันเป็นคลาส ปัญหาหลักคือ ownership และ coupling ไม่ใช่จำนวนบรรทัด

## ขอบเขตความรับผิดชอบที่ต้องการ

- **Gameplay:** ประกอบ player, camera, pond, fishing, HUD; เชื่อม signal; จัดการ pause, กลับเมนู และผลการจับปลา
- **Pond:** เจ้าของพื้นที่น้ำ/ท่าเรือ, population, bait reservation และกติกาพื้นที่; เปิด API ให้ fishing เรียกโดยไม่รู้รูปทรงภายใน
- **FishingController:** เจ้าของสถานะ READY → CASTING → WAITING → BITE → FIGHT → RESULT/LOST และคำสั่ง cast/strike/cancel/resolve
- **Fight simulation:** ถ้าแยกในระยะถัดไป ให้เป็น RefCounted ที่คำนวณจาก input, state, delta; controller จัดการ signal และตัดสินผล
- **HUD และฉากลูก:** แสดงข้อมูลและ emit ความตั้งใจของผู้เล่น; ไม่เขียน state ของ pond/controller โดยตรง
- **FishCollection:** บริการถาวรสำหรับสถิติและเซฟ; ไม่เพิ่ม global event bus หรือ Autoload สำหรับ session
- **Resources:** species เป็นข้อมูลชนิดปลา; FishState เป็นข้อมูล mutable ของปลาแต่ละตัว; tuning เป็นค่าปรับ ไม่เก็บ runtime state ลง Resource ที่แชร์

ตัวอย่าง API ที่จะเพิ่ม: `hud.is_collection_open()`, `hud.close_collection()`, `collection_open_requested`, `rod_control.set_battle_mode()`, `pond.can_land_fish()`, `player.set_movement_mode()` ชื่อสุดท้ายเลือกให้เข้ากับโค้ดระหว่างทำ

## โครงสร้างเป้าหมายแบบเพิ่มทีละส่วน

```text
features/gameplay/
  gameplay.tscn / gameplay.gd
  camera_rig.tscn / camera_rig.gd
features/fishing/
  fishing_controller.gd
  fishing_tuning.gd / default_fishing_tuning.tres
  fishing_effects.tscn / fishing_effects.gd
  fishing_hud.tscn / fishing_hud.gd
  ui/
    rod_control.tscn / rod_control.gd
    catch_result.tscn / catch_result.gd
  simulation/
    fight_simulation.gd        เพิ่มเฉพาะระยะ 4
features/collection/
  fish_collection.gd
  collection_store.gd
  collection_panel.tscn / collection_panel.gd
  collection_row.tscn / collection_row.gd
world/pond/
  pond.tscn / pond.gd
  pond_ecosystem.gd
  pond_definition.gd / default_pond.tres
  fish_state.gd
  fish_visual.tscn / fish_visual.gd
  models/                     เก็บของเดิม
```

ไม่ต้องย้าย data/fish หรือ models เพียงเพื่อให้ชื่อ folder เหมือนตัวอย่าง และยังไม่สร้างโครงระบบอุปกรณ์/หลายแผนที่ที่ยังไม่มีผู้ใช้จริง

## แผนดำเนินการ

### ระยะ 0 — บันทึกพฤติกรรมเดิมและทำ verification ให้เรียกซ้ำได้

1. ตรวจสถานะ version control และ checkpoint งานปัจจุบันก่อนเริ่มแก้ runtime
2. บันทึกเวอร์ชัน engine จริงและคำสั่งรัน tests ใน `tests/README.md`; เพิ่ม runner ที่แยก headless กับ render tests และสร้าง output directory ให้ก่อนรัน
3. รัน simulation, catalog, models, collection ที่มีอยู่แล้วเป็น baseline; บันทึกข้อผิดพลาดเดิมแยกจากข้อผิดพลาดที่ refactor ทำให้เกิด
4. ให้ test save ใช้ตำแหน่งแยกจากเซฟผู้เล่น และเก็บภาพ baseline ของเมนู, HUD, fight, result, collection

**ผ่านเมื่อ:** เรียกทดสอบซ้ำได้, ทราบ baseline และไม่มีการเขียนทับเซฟใช้งานจริง

### ระยะ 1 — ปิดการเข้าถึง internals และแยกกล้อง

1. เพิ่ม API/signal ของ HUD สำหรับ collection และ API ของ rod control สำหรับ battle mode
2. ย้าย follow, yaw/pitch, finger/mouse ownership และ focus-reset ไป `camera_rig.tscn/.gd`
3. gameplay ส่ง target/enabled ให้กล้องและส่งคำสั่งตกปลา; คงการเลือก keyboard กับ joystick ไว้จุดเดียว
4. ให้ player เป็นเจ้าของ visual rotation, rod presentation และค่าความเร็ว; gameplay เรียก public API
5. เพิ่มชนิดข้อมูลเฉพาะที่ขอบเขตนี้ โดยคง public behavior เดิม

**ผ่านเมื่อ:** gameplay ไม่เจาะโหนดภายใน HUD/player; เดินพร้อมหมุนกล้องและใช้สอง joystick ได้; เปิด collection, RESULT และเสีย focus แล้ว input ไม่ค้าง

### ระยะ 2 — แยกฉากและรวมกติกาพื้นที่

1. ย้าย World และทรัพยากรที่เกี่ยวข้องออกจาก gameplay เป็น `pond.tscn`; รักษา transform, collision, material และแสงเดิม
2. แยก `fishing_effects.tscn` พร้อม Line, AimMarker, Bobber, Ripple, FishVisuals และ audio nodes; inject controller/player/rod tip/ecosystem จาก parent
3. ให้ `PondDefinition` เก็บ bounds และค่าที่อธิบายสถานที่เดียวกัน; ให้ pond มี query สำหรับพื้นที่เดิน/น้ำ/จุดขึ้นปลา โดยยังใช้สูตรเดิมก่อน
4. เปลี่ยน player และ controller ให้เรียก pond API แทน hardcoded pier bounds
5. อัปเดต tests ที่อ้าง node path เดิมเฉพาะจุดประกอบฉาก; อย่าเปลี่ยน expected gameplay เพื่อให้ test ผ่าน

**ผ่านเมื่อ:** เปิด pond/effects แยกใน Editor ได้และเห็น authored nodes ก่อน Play; เหวี่ยง/ปลาไม่ทะลุท่าเรือ; ยืนขอบท่าจับปลาได้เหมือน baseline

### ระยะ 3 — ทำข้อมูล UI และ tuning ให้ชัด

1. รวม cast duration และค่าปรับที่สัมพันธ์กันลง `FishingTuning`; effects ใช้ progress จาก controller ไม่คำนวณด้วยค่าคงที่ซ้ำ
2. เชื่อม `state_changed` เพื่ออัปเดต visibility/ข้อความเมื่อเปลี่ยนสถานะ; ค่า tension, distance และ animation ยังอัปเดตต่อเนื่องได้
3. ใช้ `population_changed` สำหรับ ecology หลังตรวจว่าทุกทางเพิ่ม/ลด/รีเซ็ต population emit ครบ; refresh เมื่อเปิด panel ด้วย
4. แยก `catch_result.tscn` และ `rod_control.tscn` ให้ดูแล internals ของตน; เก็บ Theme เดิมและปรับผ่าน Inspector ได้
5. เพิ่ม `collection_row.bind(...)`; จัด grid ตาม resize/จำนวนรายการแทนทุกเฟรม; session เป็นเจ้าของ pause และคืนสถานะเดิมเมื่อปิด

**ผ่านเมื่อ:** เปลี่ยน cast duration จุดเดียวแล้วสถานะกับภาพตรงกัน; UI ครบทุก state; safe area/สัดส่วนกว้างและภาษาไทยยังแสดงถูกต้อง

### ระยะ 4 — แยก simulation และ persistence เท่าที่จำเป็น

1. หลังระยะก่อนนิ่งแล้ว ค่อยแยก `_fight_step()` เป็นตัวคำนวณที่ไม่มี SceneTree; ระบุให้ชัดว่าใครเขียน fish position/stamina ได้ในแต่ละ state
2. controller คุม transition และส่งผลไป pond; แยก geometry constraint ออกจากสูตร fight โดยรักษาลำดับคำนวณเดิม
3. แยก `CollectionStore` สำหรับอ่าน/ตรวจ/เขียน ConfigFile; คงชื่อ Autoload, path `user://fish_collection.cfg`, version 1, species IDs และ atomic temp+rename
4. ให้ผล record catch เป็นข้อมูล เช่น new discovery/new record/save status แล้ว UI สร้างข้อความ; รักษา API เดิมผ่าน façade ระหว่างย้ายผู้เรียก

**ผ่านเมื่อ:** ทดสอบ fight แบบ deterministic โดยไม่ instantiate gameplay; สูตรและ outcome ตรง baseline; เซฟเก่าอ่านได้และ incompatible save ไม่ถูกเขียนทับ

**เงื่อนไขลด scope:** ถ้าแยก fight แล้วเกิด wrapper มากกว่าประโยชน์ ให้คง controller เดิมที่มี API/type ชัดเจนไว้ก่อน ไม่ต้องสร้าง state class หนึ่งตัวต่อสถานะ

### ระยะ 5 — เอกสารและเครื่องมือ

1. เพิ่ม README สำหรับเริ่มเกม, architecture, scene ที่แก้, tests และ release
2. รับ Godot/Java/SDK/cache paths ผ่าน arguments หรือ local config ที่ไม่ commit; คง signing identity เดิม
3. ให้ build/verifier ใช้ version/artifact ที่ระบุชัด ลดชื่อ release และ path intermediate ที่ฝังไว้
4. รวม log/QA output ใน `exports/qa/` และตรวจ reference ก่อนย้าย asset หรือเครื่องมือเก่า; ไม่ลบ source art ที่ยังไม่ทราบผู้ใช้งาน
5. ตรวจ export exclusions ใหม่ถ้ามีการย้ายไฟล์ เพื่อไม่ให้ source tools/test artifacts หลุดเข้าแพ็กเกจ

**ผ่านเมื่อ:** ตั้งค่าที่ตั้ง runtime ได้โดยไม่แก้ source; build verification ใช้ artifact ของรอบนั้นจริง; resource references ไม่มี path เสีย

## การทดสอบและข้อควรรักษา

- ใช้ `fishing_simulation_test.gd`, `fish_catalog_fishing_test.gd`, `fish_models_test.gd` ตรวจ behavior/data เดิม
- ใช้ `collection_test.gd` ตรวจเซฟ สถิติ และข้อผิดพลาด; เพิ่มกรณีเท่าที่ขอบเขตใหม่เปลี่ยนความเสี่ยงจริง
- ใช้ `fishing_visual_test.gd`, `fish_render_test.gd` ในโหมดมี renderer สำหรับภาพและ input; headless ผ่านไม่ได้แปลว่าภาพถูกต้อง
- เมื่อแก้ scene ให้ import/parse ด้วย engine เดิมและอ่าน log แล้วตรวจ Editor preview
- รักษาจังหวะลง collection เมื่อ `fish_landed` ก่อนเลือกเก็บ/ปล่อย; อย่าย้ายการบันทึกไปเฉพาะ keep โดยเผลอเปลี่ยนกติกา
- รักษา positive Y = depth ใน FishState และการแปลงเป็น world position; อย่าเปลี่ยนหน่วย/แกนพร้อมกับย้าย ownership
- ไม่เปลี่ยน enum ordering โดยไม่แก้ผู้ใช้งาน เพราะ HUD เดิมผูกข้อความกับ index
- ย้าย resource พร้อม UID/import metadata ที่เกี่ยวข้อง และอัปเดต preload, ext_resource, exports และ tests ในชุดเปลี่ยนเดียว
- ทดสอบ Android จริงสำหรับ multi-touch, focus loss, back, safe area, save/reopen และ vibration เมื่อเริ่มลงมือ; เครื่องมือ desktop อย่างเดียวไม่ยืนยันผลบนอุปกรณ์

แต่ละระยะควรเป็นชุดเปลี่ยนที่รันได้และย้อนกลับแยกกัน หากผลต่างจาก baseline ให้แก้ก่อนทำระยะถัดไป ไม่รวมการปรับ balance/หน้าตาใหม่กับ refactor

## ขอบเขตการสำรวจครั้งนี้

อ่าน project configuration, scripts หลัก, node structure ของ gameplay, ส่วนต้น/จุดตรวจของชุดทดสอบ และเครื่องมือ release แล้ว ยังไม่ได้รันเกม/tests หรือยืนยันผลบน Android เพราะครั้งนี้เป็นการจัดทำแผน

ไม่พบ AGENTS.md จากการค้นหาในขอบเขต source ที่เข้าถึงได้; โฟลเดอร์ signing ถูกจำกัดสิทธิ์และไม่ได้ตรวจเนื้อหา ส่วน `git status` ไม่สำเร็จเนื่องจาก permission ของ path จึงยังไม่ยืนยันความสะอาดของ working tree

แนะนำเริ่มระยะ 0–1 เป็นงานชุดแรก เพราะลดการผูกกับ UI และแยกกล้องได้โดยยังไม่เปลี่ยนสูตรตกปลา เซฟ หรือรูปร่างบ่อ
