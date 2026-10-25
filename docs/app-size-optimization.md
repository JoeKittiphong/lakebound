# ตรวจขนาดแอปและโมเดลฉาก — 23 ตุลาคม 2026

## ผลสุดท้ายที่วัดจากบิลด์จริง

บิลด์ AAB แบบ release ด้วยคีย์ QA แยกสำเร็จ แล้วใช้ bundletool/device spec เดียวกับไฟล์เดิม:

| ตัววัด | AAB 0.1.8 เดิมในเครื่อง | บิลด์ QA หลังปรับ |
|---|---:|---:|
| ขนาดไฟล์ AAB | 63.78 MiB | 57.35 MiB |
| ดาวน์โหลด ARM64 (decimal MB) | 40.70 MB | 33.95 MB |
| ดาวน์โหลด ARM64 (MiB) | 38.81 MiB | 32.37 MiB |
| เนื้อหาเกมใน AAB แบบบีบอัด | 12.68 MiB | 6.24 MiB |

ยอดดาวน์โหลดจากการคำนวณของ bundletool ลด **6,752,824 bytes (~16.6%)** Native libraries ทั้งสี่ไฟล์ของ ARM32/ARM64 มี SHA-256 ตรงกับเดิมทั้งหมด ไม่มีการตัด CPU ที่รองรับออกจาก AAB และไม่ลดโมเดล/จำนวนพืช

ไฟล์ `exports/size-audit/optimized-qa-only.aab` ใช้สำหรับตรวจขนาดเท่านั้น **ห้ามใช้แทนบิลด์ที่เซ็นด้วย production upload key เพื่อส่ง Play** ไม่มีการอัปโหลดในงานนี้ การแสดง 100 กว่า MB บน Play ยังต้องเทียบ artifact/version จริงแยกต่างหาก

หลักฐาน: `qa-aab-result.json`, `optimized-download-size.log`, `optimized-archive.json`, `native-comparison.json`

## ประเด็นสำคัญ: ผู้ใช้หมายถึงขนาดดาวน์โหลดใน Google Play

อย่าใช้ขนาด universal APK, ขนาดไฟล์ AAB, ขนาดติดตั้ง และขนาดดาวน์โหลดจาก Play แทนกัน ผู้ใช้ยืนยันว่าตัวเลข 31 → 100 กว่า MB มาจาก Google Play การวิเคราะห์ APK ด้านล่างจึงเป็นข้อมูลประกอบ ไม่ใช่คำยืนยันสาเหตุของตัวเลขนั้น

ใช้ bundletool 1.16.0 ที่มีอยู่ใน Gradle cache สร้าง device-specific APK set จาก AAB `lakebound-0.1.8-closed.aab` แล้วรัน `get-size total` สำหรับ ARM64, SDK 35, density 420, locale en:

**40,699,467 bytes = 40.70 MB = 38.81 MiB**

เป็นค่าประเมินดาวน์โหลดของ AAB ที่มีในเครื่อง ไม่ใช่ข้อมูลสดจาก Play Console และยังไม่ได้ยืนยันว่าเป็น artifact/version/device เดียวกับหน้าที่แสดง 100 กว่า MB จึงยังสรุปไม่ได้ว่าการกระโดดนั้นเกิดจากโมเดลหรือการแพ็กอะไร ต้องเทียบ version code และ device ใน Play ต่อ

หลักฐาน: `exports/size-audit/download-size.log`, `arm64-device.json` และ AAB เดิม ชุด .apks และ staged project เป็นไฟล์ชั่วคราวที่ล้างหลังวัดเพื่อลดพื้นที่ทำงาน เก็บ AAB สำหรับ QA, PCK, JSON และ logs ไว้ การเซ็นชุดทดสอบใช้คีย์ QA แยกในโฟลเดอร์ exports ไม่ได้ใช้หรือแก้คีย์เผยแพร่

## สิ่งที่พบจากไฟล์จริง

| Artifact ในเครื่อง | ขนาดไฟล์ | native libraries ที่อยู่ใน archive | เนื้อหาเกมที่อยู่ใน archive |
|---|---:|---:|---:|
| APK Playtest เดิม | 151.95 MiB | ARM32 72.39 + ARM64 69.13 MiB ไม่บีบอัด | 4.38 MiB |
| AAB 0.1.0 | 55.24 MiB | บีบอัด ARM32 24.71 + ARM64 23.34 MiB | 4.33 MiB |
| AAB 0.1.8 | 63.78 MiB | ขนาด native เหมือน 0.1.0 | 12.68 MiB |

เนื้อหาเกมใน AAB เพิ่มประมาณ 8.35 MiB ระหว่างสองไฟล์นี้ ตัว engine ยังเท่าเดิม โมเดลตัวละคร `angler_994.glb` ใน source ประมาณ 0.39 MiB จึงไม่ใช่ไฟล์ระดับหลายสิบ MB

เครื่องมือทำซ้ำ: `tools/audit_app_size.py`; ผลละเอียดและรายการไฟล์ใหญ่: `exports/size-audit/archives.json`

## การใช้ instance ในฉากปัจจุบัน

ตรวจ resource จริงของ `river_world.tscn` โดย instantiate แบบไม่เพิ่มเข้า SceneTree:

- node รวม 2,709
- MeshInstance3D 873 nodes (รวมลูกของ scene instances)
- MultiMeshInstance3D 470 กลุ่ม วาดพืชรวม 9,157 instances
- mesh resources ที่ถูกอ้างจาก visual nodes ไม่ซ้ำ 280 ตัว
- ไฟล์ฉากมี PackedScene instance references 514 จุด

แปลว่าฉากใช้งาน instancing อยู่แล้ว ไม่ได้เก็บโมเดลพืช 9,157 ก้อนเป็น node แยกทั้งหมด

| วิธี | ผลต่อเครื่อง | ผลต่อขนาดแอป |
|---|---|---|
| scene instance (.tscn) ใช้ mesh/material ร่วม | ลดข้อมูลซ้ำในหน่วยความจำ แต่ยังมี node และการส่งวาดแต่ละวัตถุ | เล็กกว่าการฝังสำเนา mesh เมื่อใช้ resource ร่วมจริง |
| MultiMesh แบ่งกลุ่มตามพื้นที่และชนิด | ลด node/draw submission สำหรับของซ้ำจำนวนมาก แต่ culling เป็นกลุ่ม | ลดข้อมูลสำเนาเมื่ออ้าง mesh เดียว แต่ยังต้องมีข้อมูล transform แต่ละ instance |
| ฝัง/duplicate geometry ใหม่ทุกชิ้น | เสี่ยงใช้ RAM/VRAM มากกว่าเมื่อเป็น resource คนละตัว | มีโอกาสแพ็ก mesh ซ้ำ |

ควรคง MultiMesh ของพืชที่มีอยู่ และใช้ scene instances สำหรับสะพาน/หิน/ต้นไม้ที่ต้องมี collision หรือปรับแต่งใน Editor ไม่ควรรวมทั้งแผนที่เป็น MultiMesh เดียว เพราะเสียการคัดวัตถุนอกกล้องเป็นรายพื้นที่ งานรอบนี้ไม่เปลี่ยนโมเดล จำนวนพืช ชนิดปลา collision หรือรูปทรงฉาก

เครื่องมือตรวจซ้ำ: `tools/audit_scene_size.gd`; ผล: `exports/size-audit/scene.json`

## การลดที่ทำแล้ว

### 1. กันไฟล์ประกอบฉากและ texture สำเนาที่ไม่ได้ใช้ ออกจากทุก export preset

- `river_manifest.json`: ใช้โดย tools/assemble_river.gd
- `river_props.glb`, `river_terrain.glb`: ต้นฉบับสำหรับประกอบฉาก; runtime ใช้ฉาก/mesh ที่ serialize ไว้แล้ว
- `foliage_atlas_512.png`, `river_terrain_foliage_atlas_512.png`
- `wetland_atlas_256.png`, `river_terrain_wetland_atlas_256.png`

เก็บ `river_props_foliage_atlas_512.png` และ `river_props_wetland_atlas_256.png` ที่ material ใช้งานจริงไว้ สำเนามี SHA-256 เท่ากัน แต่ preset การ import ต่างกัน จึงไม่สลับ runtime texture ไปใช้สำเนาที่ import คนละแบบ

รายการข้างต้นอยู่ใน AAB 0.1.8 รวม **2,172,642 bytes (~2.07 MiB แบบบีบอัด)** หลักฐาน `excluded-existing-aab.json` เป็นขนาดจาก artifact เก่า ไม่ใช่ผลบิลด์ใหม่

### 2. บีบอัดภาพพื้นหลังและโลโก้ โดยรักษาความละเอียดเดิม

แก้เฉพาะการ import ไม่แตะ PNG ต้นฉบับ:

| ภาพ | .ctex เดิม | .ctex ใหม่ | Sampled RGB PSNR |
|---|---:|---:|---:|
| loading_lake | 1,767,488 B | 235,510 B | 36.56 dB |
| menu_lake | 1,682,080 B | 209,674 B | 37.04 dB |
| logo | 1,719,986 B | 472,906 B | 34.79 dB |

รวมลดขนาด imported textures **4,251,464 bytes (~4.05 MiB)** ก่อนคำนวณการบีบอัดซ้อนของ archive ภาพพื้นหลัง quality 0.85 โลโก้ 0.95 รักษาขนาด 1672×941 และ 1536×1024 ตามเดิม

เคยทดลองลดโลโก้เหลือ 768 แต่ตรวจคุณภาพไม่ผ่านเกณฑ์ จึงคืนความละเอียดเดิมและเพิ่ม quality ไม่ฝืนลดจนรายละเอียดเสีย

การบีบอัดแบบนี้ลดพื้นที่ไฟล์ ไม่ได้ทำให้ GPU texture ที่มีความละเอียดเท่าเดิมใช้ RAM ลดลงในสัดส่วนเดียวกัน หลักฐาน `texture-before.json`, `texture-after.json`, `texture-console.log`

### 3. แยกการปรับ APK สำหรับทดสอบ ออกจาก AAB สำหรับ Play

- Android APK Playtest: เปิด native compression แต่ยังเก็บ ARM32 + ARM64
- Android APK Compact ARM64: preset ใหม่ native compression เปิด, ARM64 เท่านั้น, output `exports/android/lakebound-compact-arm64.apk`
- Android AAB: ยังรองรับทั้ง ARM32 + ARM64 ไม่มีการตัดอุปกรณ์เก่าออกจาก Play โดยพลการ

บีบอัด native payload จาก APK เดิมเพื่อคำนวณ ได้ขนาดประมาณ 58.45 MiB สำหรับ universal หรือ 33.74 MiB สำหรับ ARM64 เท่านั้น ก่อน overhead ของการแพ็ก/เซ็นและก่อนเนื้อหาเวอร์ชันใหม่ **ไม่ใช่ APK ใหม่ที่บิลด์สำเร็จ และไม่ใช่ยอดดาวน์โหลดบน Play**

## ข้อเสนอถัดไปตามลำดับความคุ้มค่า

1. ใช้ผลบิลด์ QA ที่วัดแล้วเทียบกับหน้า App size ของ Play version/device เดียวกัน จากนั้นค่อยทำ production-signed build ตามขั้นตอนเผยแพร่เดิม ไม่ใช้ขนาด APK รวมเป็นตัวตัดสิน
2. หากต้องเล็กลงอีกอย่างมีนัยสำคัญ ให้ทำ custom release export template ของ Godot ตัด modules ที่เกมไม่ได้ใช้ พร้อมทดสอบ engine/features ที่เกมต้องใช้จริง วิธีนี้มีโอกาสลดส่วนที่ใหญ่ที่สุด แต่ยังไม่มี template/build เพื่อยืนยันตัวเลข
3. ลดขนาด/คุณภาพ texture หรือ LOD เพิ่มเฉพาะจุดจากภาพจริงและ profiler ไม่ลดจำนวนพืชหรือรายละเอียดฉากก่อนพิสูจน์ว่าเป็นคอขวด
4. วิเคราะห์ draw calls/GPU time บนมือถือจริงก่อนเปลี่ยนกลุ่ม trees/rocks เป็น MultiMesh เพิ่ม เพราะการลดขนาดดาวน์โหลดกับลดภาระเรนเดอร์เป็นคนละเรื่อง

## การตรวจและข้อจำกัด

- import ผ่าน, export preset validation 18 checks ผ่าน
- texture comparison 3 checks ผ่าน รวมเงื่อนไขขนาดลดและ PSNR >=32 dB
- regression headless import + 15 suites ผ่าน 16/16 entries
- ตรวจภาพจริงเมนู/โหลดและ UI ที่ 1280×720 และ 1600×720 ผ่านชุด visual 28 checks และตรวจด้วยสายตา
- อ่าน AAB เดิมและสร้าง device-specific APK set ด้วย bundletool สำเร็จ ไม่ได้อัปโหลดหรือเผยแพร่
- การ export-pack จาก working project เดิมค้างใน Packing จึงหยุดหลัง timeout แล้วสร้าง clean staged project เฉพาะ runtime sources ผล import และ export-pack สำเร็จ ได้ PCK 12,173,256 bytes (~11.61 MiB)
- ทดสอบ PCK ที่ export จริง: `packed_size_test.gd` 29 checks ผ่าน ยืนยันไฟล์ที่ตัดไม่อยู่ใน pack, runtime textures และโมเดลปลา 16 ชนิดยังอยู่ และ startup flow เปิดเมนู → เกม → กลับเมนูผ่าน
- startup fixture ของ PCK มี ObjectDB warning 11 instances ตอนปิด จึงเพิ่มการตรวจเปิด/ปิด gameplay ซ้ำสี่รอบ: resource count คงที่ `[1709, 1709, 1709, 1709]`, node count `[3, 3, 3, 3]` ไม่พบการสะสมใน smoke test นี้ ไม่ถือเป็นการรับรอง RAM ของ Android
- บิลด์ QA AAB จาก staging สำเร็จหลังอนุญาตให้ build tool เขียนล็อกใน Gradle cache ที่ติดตั้งไว้ ใช้เฉพาะ QA signing identity และวัดดาวน์โหลดด้วย bundletool อีกครั้งแล้ว
- ยังไม่ได้ทดสอบ FPS/RAM บน Android เครื่องจริง และยังไม่ได้เห็น artifact/version ที่ทำให้ Play แสดง 100 กว่า MB

## เอกสารอ้างอิงหลัก

- [Godot 4.7 MultiMesh](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html)
- [Android: ลดขนาดแอป](https://developer.android.com/topic/performance/reduce-apk-size)
- [Android: bundletool และ get-size](https://developer.android.com/tools/bundletool)
- [Play Console: App size เป็น compressed download size](https://support.google.com/googleplay/android-developer/answer/9859372?hl=en)
