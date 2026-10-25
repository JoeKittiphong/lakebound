# แผนที่และภารกิจ Lakebound

เพิ่มแผนที่ใหม่ 5 โซน เลือกเข้าเล่นได้จากหน้าหลัก พร้อมคงแม่น้ำและข้อมูลผู้เล่นเดิม

| เมนู | ฉากเล่น | ปลาใน roster | ภารกิจ |
|---|---|---:|---:|
| แม่น้ำสายใหญ่ | res://features/regions/grand_river.tscn | 28 | 12 เดิม |
| บึงบัวริมทุ่ง | res://features/regions/lotus_marsh.tscn | 14 | 6 ใหม่ |
| ลำธารป่าภูเขา | res://features/regions/forest_stream.tscn | 28 | 6 ใหม่ |
| เขื่อนดงตอไม้ | res://features/regions/wild_reservoir.tscn | 14 | 6 ใหม่ |
| ปากอ่าวป่าชายเลน | res://features/regions/mangrove_estuary.tscn | 14 | 6 ใหม่ |
| ทะเลแนวปะการัง | res://features/regions/coral_coast.tscn | 15 | 6 ใหม่ |

แผนที่ลำธารรวมปลาจากสารานุกรมโซน 3 และ 5 เพื่อให้แผนที่ใหม่ทั้งห้าครอบคลุมสารานุกรมครบ 100 รายการ ร่วมกับแม่น้ำเดิม มีปลาเดิมนอกสารานุกรมอีก 5 แบบที่เก็บไว้ สมุดสะสมจึงมีทั้งหมด 105 รายการ

## การเล่น

หน้าโหลด → หน้าหลัก → เลือกแหล่งน้ำ → แตะโซน → เริ่มตกปลา ทุกโซนเลือกเข้าเล่นได้ทันที ตัวเลือกแผนที่ใช้ปุ่มสัมผัสและ ScrollContainer แบบลากได้ทั้งการ์ด บนจอแคบเปลี่ยนเป็นคอลัมน์เดียวและขยายข้อความ

แต่ละโซนมีปลาเกิดอยู่ก่อนเหวี่ยงเบ็ด ไม่สร้างปลาขึ้นเพื่อตอบการ cast มีท่าน้ำ เรือ ทางเดินชายฝั่ง พื้นน้ำตื้น/น้ำลึก และระบบว่ายน้ำ ใช้เหยื่อ/ปรับความลึกในกระเป๋าและแผงความลึกให้ตรงกับปลา โซนทะเลปรับได้ถึง 28 ม.; เขื่อนถึง 16 ม.

- บึงบัว: แอ่งน้ำนิ่งตื้น กอบัว/บัวโผล่น้ำ และปลากระดี่/ปลาหมอ
- ลำธารป่าภูเขา: ลำน้ำคดแคบ หินใหญ่ ป่าสนและต้นไม้ป่าลึก ปลาพลวง กระสูบ และกลุ่มปลาป่า
- เขื่อน: แอ่งลึก แนวผนังเขื่อน ตอไม้/ต้นไม้ตายจมน้ำ ชะโดและปลาฝูงเขื่อน
- ปากอ่าว: ร่องน้ำคด เกาะชายเลนและรากไม้ริมน้ำ กะพง ปลาตีน และปลาน้ำกร่อย
- ทะเล: หาดทราย ปาล์ม แนวหิน/ปะการังใต้น้ำ และปลาทะเลรวมทูน่ากับกระโทง

## ภารกิจและข้อมูลเดิม

เพิ่ม 30 ภารกิจใหม่ แบ่งโซนละ 6: เปิดบันทึกจำนวนปลา, สำรวจชนิด, ปลาประจำพื้นที่, น้ำหนักสะสม, การตกแบบเฉพาะถิ่น และปลาท้าทายประจำโซน เช่น กระสูบกับเหยื่อปลอม, ชะโดดงตอ, กะพงปากอ่าว และเก๋าจุดฟ้า

MissionPanel แสดงเฉพาะภารกิจของแผนที่ที่เล่น การติดตามและ catch event ผูก map_id; รางวัลมีการป้องกันรับซ้ำ ปลาในแต่ละบ่อบันทึกแยกชื่อพื้นที่

แม่น้ำใช้ save key `river` เดิม รวม 16 species resources เดิมที่คงช่วงน้ำหนักเดิม และเพิ่มอีก 12 ชนิดจากสารานุกรม จึงอ่านประชากรเก่าได้โดยไม่ลบทิ้ง ปลาใหม่เข้ามาในการเติมประชากรตามระบบเดิม สมุดสะสม เหรียญ เหยื่อ ความยาวสาย และความคืบหน้า 12 ภารกิจเดิมยังคงอยู่

## เปิดแก้ใน Godot Editor

- หน้าหลัก: res://features/menu/main_menu.tscn
- ตัวเลือกแผนที่: res://features/menu/region_selector.tscn
- รายชื่อโซน/ข้อความ: res://data/regions/region_catalog.gd
- ฉากโลกใหม่: res://world/regions/<zone>/world.tscn มี Terrain, Jetty, Scenery/Rocks, Trees, Plants, Landmarks และ GameplayMarkers
- terrain.res เป็น mesh ภูมิประเทศ; definition.tres เป็น Resource ระบุระดับพื้น/ความลึกที่ใช้กับปลา เรือ และว่ายน้ำ
- เปลี่ยนตำแหน่ง props/แสง/วัสดุได้ในฉากโดยตรง หากเปลี่ยนพารามิเตอร์รูปภูมิประเทศใน definition ต้องสร้าง mesh และ collision ใหม่ให้ตรงกันด้วย tools/build_regions.gd
- ข้อมูลปลา: res://data/fish/encyclopedia/*.tres
- ภารกิจ: res://data/missions/<zone>_*.tres
- ต้นฉบับโมเดลและรายงานครบ 100 รายการ: art/fish/encyclopedia-100/README.md

## ผลการตรวจ

- fish_encyclopedia_test.gd: 2,002 checks, 0 failures — โมเดล/skin/texture/3 clips และการวนอนิเมชันครบ 100 รายการ
- regions_integration_test.gd: 854 checks, 0 failures — roster, terrain, jump, swimming, boat, cast, mission matching/completion/reward, six-map selection, mobile swipes, enter/back และ save namespaces
- regions_fishing_test.gd: 60 checks, 0 failures — ปลาเดิมในระบบเข้ากินเหยื่อตามธรรมชาติ วัดเบ็ด สู้จนขึ้น เก็บปลา และนำออกจาก saved population ของโซนที่ถูกต้อง ครบหกแหล่งน้ำ (ใช้ชุดอุปกรณ์หนักใน QA)
- regions_legacy_save_test.gd: 7 checks, 0 failures — ประชากรเดิม 112 ตัว/identity/น้ำหนัก เหรียญ เหยื่อ สาย และภารกิจเดิม
- missions_test.gd: 76 checks, 0 failures
- economy_test.gd: 40 checks, 0 failures
- collection_test.gd: 0 failures
- mobile_collection_test.gd: 3,270 checks, 0 failures — สมุดสะสม 105 รายการยังเลื่อนถึงรายการสุดท้ายและแสดงภาพโดยใช้สอง atlas ไม่ใช้ 3D viewport ในแต่ละช่อง
- loading_flow_test.gd: 0 failures

ตรวจภาพจริงใน Godot ครบทุกโซน ภาพเก็บใน exports/qa-traversal/screenshots/regions_*.png. ตรวจบน Windows desktop renderer; ยังไม่ได้วัด FPS บนโทรศัพท์จริงหรือส่ง Android release ใหม่
