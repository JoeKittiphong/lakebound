# ผลทดสอบ Web App จริง — 28 ตุลาคม 2026

URL:
https://script.google.com/macros/s/AKfycbwP1Ui0jGty5aeR63o5dFf5G15zZQxnyrgiFRcgyHwcJ0b4hfgV3Kzwva_3ld7EmwZTdw/exec

## โหลด HTTP อ่านอันดับ

เริ่มคำขอ GET จาก client 100 workers พร้อมกัน ไม่ retry กระดานอันดับยังว่าง

| รายการ | ผล |
|---|---:|
| คำขอทั้งหมด | 100 |
| สำเร็จ | 100 |
| ล้มเหลว | 0 |
| Median | 5.641 วินาที |
| P95 | 7.547 วินาที |
| เวลารวม | 9.0 วินาที |
| JSON ตอบกลับรวม | 5,700 ไบต์ |

ผลนี้ยืนยัน burst อ่าน 100 คำขอในสภาวะที่ทดสอบ ไม่ใช่การรับรอง 100 writes พร้อมกัน
หรือการประมวลผล 100 executions พร้อมกันภายใน Google ไม่ได้วัดผู้เล่นออนไลน์สูงสุด
และยังไม่ได้ยิงโหลดกระดานที่มีข้อมูลเต็ม 100 อันดับ

ผลดิบ: `exports/qa-sheets-live/load-100.json`

## HTTP รับส่ง

Python smoke test ผ่าน 7 ข้อ: POST สมัคร guest แบบไม่มีคะแนน, POST ซ้ำพร้อมเวอร์ชันเดิม,
ปฏิเสธ token ผิด, ปฏิเสธน้ำหนักติดลบ และ GET Top10/50/100
ไม่มีคะแนน QA ถูกเพิ่มลง Ranking มีเฉพาะบัญชี QA ที่ไม่มีคะแนนสำหรับทดสอบการสมัคร

## Godot

พบและแก้ HTTP 400 จากการตาม redirect ของ Apps Script หลัง POST
ให้ตัวเกมติดตาม 302 ไปยัง `https://script.googleusercontent.com/macros/echo?…`
ด้วย GET ใหม่ที่ไม่มี POST body หรือ header เดิม ยังคงตรวจ TLS ตามปกติ
ทดสอบจริงผ่าน POST เปิดบอร์ดครั้งแรก, GET เปิดซ้ำ, ตัวกรองแผนที่ และ Top100
ใช้เซฟ QA แยกจากเซฟจริง ไม่เพิ่มคะแนนทดสอบ และเก็บ URL ใหม่ใน `online.cfg`
