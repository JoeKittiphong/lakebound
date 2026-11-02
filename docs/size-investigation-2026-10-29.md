# วิเคราะห์ขนาด Lakebound — 29 ตุลาคม 2026

หน่วย MB ในรายงานเป็นฐานสิบ (1 MB = 1,000,000 bytes) อ่านขนาดจาก AAB จริงใน exports/android เทียบรายการ ZIP แยกเนื้อหาเกมกับ native engine ไม่มีการแก้ production assets, export preset หรือเผยแพร่ release ในการตรวจครั้งนี้

## สาเหตุที่ยืนยันจากไฟล์

| รุ่น | AAB | ความเปลี่ยนแปลง |
|---|---:|---|
| 0.1.11 | 61.28 MB | เนื้อหาเกมบีบอัด 7.66 MB |
| 0.1.12 | 94.51 MB | +33.23 MB; เนื้อหาเกมเพิ่มเป็น 40.41 MB |
| 0.1.18 | 90.07 MB | หลังปรับและเพิ่มงานระหว่างรุ่น |
| 0.1.19 | 93.48 MB | +3.41 MB; atlas อุปกรณ์เพิ่ม 2.765 MB และโมเดล/ข้อมูลอุปกรณ์ใหม่ |
| 0.1.20 | 93.52 MB | +36,880 bytes จากรุ่นก่อน; ไอคอนเว็บ/สูตรเหยื่อไม่ใช่ตัวเพิ่มหลัก |

0.1.11 → 0.1.12: รายการเพิ่มใหญ่สุดคือ bridge albedo 5.768 MB, bridge normal 5.685 MB, reference rocks normal 3.967 MB และ albedo 1.306 MB ตามด้วย normal maps หินอีกสองชุดรวม 2.232 MB ขณะนั้นบาง texture สะพานยังเป็น lossless; รุ่นปัจจุบันเปลี่ยนเป็น ETC2 แล้วจึงเล็กลงจากตอนเพิ่มครั้งแรก ยังมีเนื้อหาแผนที่/ปลา/ฉากอื่นเพิ่มด้วย ไม่ควรเหมารวมว่าการเพิ่มแผนที่ทั้งหมดเป็น geometry

SHA-256 ของ native .so ทั้ง 4 ไฟล์ตรงกันระหว่าง 0.1.11 และ 0.1.20 ตัว engine ไม่ได้โต มีขนาดบีบอัดรวม 50.39 MB ใน AAB ที่บรรจุ ARM32+ARM64; ผู้เล่น Play ได้ binary ตามเครื่อง ไม่ควรบวกทั้งสอง ABI เป็นขนาดดาวน์โหลดของเครื่องหนึ่ง

## ไฟล์ใหญ่ที่ควรจัดการก่อน

| ไฟล์ | ปัจจุบันใน AAB แบบบีบอัด | ทดลอง import จำกัด 1024 | ลดได้ |
|---|---:|---:|---:|
| reference rocks normal 2048 | 3.967 MB | 1.047 MB | 2.920 MB |
| bridge normal 2048 | 3.396 MB | 1.023 MB | 2.374 MB |
| equipment atlas 2048 | 2.765 MB | 0.919 MB | 1.846 MB |
| รวม | 10.128 MB | 2.988 MB | **7.140 MB** |

ทดลองใน exports/size-investigation-2026-10-29/texture-trial เท่านั้น ด้วย Godot 4.7.2 และคง import settings เดิมทั้งหมด ยกเว้น process/size_limit=1024 จากนั้นวัด raw DEFLATE level 6 เทียบไฟล์ .ctex ตัวเดิมที่อ่านจาก AAB การบีบอัด baseline ให้จำนวน bytes ตรงกับ archive ทั้งสามไฟล์ จึงใช้ประเมินส่วนต่าง payload ได้ แต่ยังไม่ใช่ผล AAB build ใหม่หรือ Play download ใหม่

หากส่วนอื่นเท่าเดิม คาด AAB ราว 86.38 MB (93.52 - 7.14); ต้องสร้างและวัดจริงอีกครั้งก่อนใช้อ้างอิง release คุณภาพภาพ/normal map/ความคมของไอคอนยังไม่ผ่าน visual QA ของรุ่นลดขนาดนี้ โดยเฉพาะสะพานระยะใกล้และ icon preview ขนาดใหญ่

## ลำดับแก้ที่แนะนำ

1. ทดลองใช้ normal maps 1024 เฉพาะสองชุดนี้ก่อน แล้วตรวจแสง/ผิวในฉากจริงทุกแผนที่ คง albedo และ geometry เดิมไว้
2. ทดลอง equipment atlas 1024 (แต่ละช่องลดจาก 256 เป็น 128) แล้วตรวจร้านค้าและ preview บนมือถือ ถ้าเสียความคม ให้ใช้ atlas ขนาดเดิมแต่ทดลอง lossy/WebP import แทน โดยวัดทั้ง alpha edges และขนาดจริง
3. ตรวจ dependency ของทรัพยากรที่ไม่ใช้ก่อน export เพราะ preset เป็น all_resources แต่ไฟล์ preview scene ตรง ๆ ใน AAB มีเพียง 40,293 bytes รวม 28 รายการ การตัด preview scene อย่างเดียวจึงไม่ใช่ทางลดหลายสิบ MB ต้องตรวจว่ามี asset ที่ถูกดึงเข้ามาโดยไม่ใช้จริงด้วย และอย่าตัดไฟล์ที่ถูก load ด้วย path แบบ dynamic
4. ไม่ลดจำนวนชนิดปลา/อุปกรณ์/แผนที่ และไม่ตัด ARM32 เป็นลำดับแรก การตัด ABI ลดไฟล์ AAB อัปโหลด แต่ไม่ได้แปลว่าเครื่อง ARM64 บน Play จะดาวน์โหลดลดลงเท่ากัน
5. หลังปรับ ให้สร้าง AAB QA และใช้ bundletool get-size total เทียบ device spec เดียวกัน ตรวจภาพและเล่นครบทุกแผนที่ก่อนเปลี่ยน release

## ขนาดดาวน์โหลดกับขนาดติดตั้ง

บันทึก release เดิมใน repository ระบุ Play new-install download: 0.1.11 = 35.2 MB, 0.1.12 = 68 MB, 0.1.20 = 66.8 MB ไม่ใช่การอ่าน Play Console สดในงานนี้ ขนาดติดตั้งหลังแตกไฟล์และ update download เป็นคนละตัวชี้วัด จึงยังไม่ยืนยันตัวเลขบนเครื่องของผู้ใช้จาก AAB อย่างเดียว

หลักฐานเครื่องอ่านได้: exports/size-investigation-2026-10-29/findings.json

เอกสารหลัก:
- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html
- https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html
- https://developer.android.com/tools/bundletool
