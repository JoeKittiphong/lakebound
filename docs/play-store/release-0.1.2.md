# Lakebound 0.1.2 / version code 3

The requested latest local artifact was `lakebound-fishing-water-release.aab` (20 October 2026, 07:29). Its export configuration reused version code 2 and used the alternate editor signing certificate. Code 2 was already uploaded to Play. Re-exported the current fishing/water project using code 3 / version 0.1.2 and the original upload identity, without changing gameplay code. Updated the stale prototype/menu version labels to match the fishing build.

Signed output: `exports/android/lakebound-0.1.2-closed.aab`.
SHA-256: `55fdd2fb80607229f4c34dd4b766292594e11db668f8f8b95afc66cd4b0199fe`.
Upload certificate SHA-256: `22148E753332B6E25C4CF63A54E1D1604F2A48FC2ECB77245921C1A4DC6994B7` (matches first Play bundle).

Godot release export and GPU menu/play/movement/back smoke check passed. Refreshed actual desktop screenshots. Package checks passed: no private signing/test files, API 36, code 3, ARM64 ELF 16 KB alignment. Only VIBRATE permission is requested for bite feedback; no internet/storage/location/microphone access. No physical-device test in this upload task.

Play accepted bundle 3 (0.1.2) in closed Alpha release 3. Old bundle 2 is excluded; device support is unchanged. Updated and saved Thai store copy and three actual screenshots to match the playable fishing build. Existing AI labels preserved for icon/feature art; menu screenshot is labeled because it contains the generated background documented in `docs/prototype_notes.md`. Auto-review initially blocked that label; after verifying its source and scene reference, the same accurate label/save action was permitted. Gameplay screenshots remain unlabeled.

## Submission status

Bundle 3 and updated listing are saved as four pending changes. The previous 0.1.1 review is still running. Google warns that submitting 0.1.2 will cancel and restart the current review, increasing the wait. Automatic approval review rejected confirmation of that restart because the user's upload request did not explicitly authorize this warned queue interruption. Asked the user for that specific permission; do not confirm the restart until their answer arrives.
Proof: `exports/play-store/0.1.2-review-restart-confirmation.png`.

## Release notes
<th>
รุ่นทดสอบแบบปิด 0.1.2
เพิ่มระบบตกปลา เลือกเหยื่อและความลึก เหวี่ยงเบ็ด และควบคุมสาย
เลือกเก็บหรือปล่อยปลาที่ตกได้
ปรับขอบเขตน้ำและการดึงปลาเข้าฝั่ง
</th>

## Updated store text
Short: ทดสอบตกปลาในทะเลสาบสามมิติ เหวี่ยงเบ็ด คุมสาย และสำรวจริมบ่อ

Lakebound เป็นเกมตกปลาสามมิติที่กำลังพัฒนา เดินสำรวจริมทะเลสาบ เลือกเหยื่อและความลึก แล้วเหวี่ยงเบ็ดเพื่อทดสอบฝีมือกับปลาในบ่อ

สิ่งที่เล่นได้ในรุ่นทดสอบ
• เดินและควบคุมคันเบ็ดด้วยจอยสัมผัสสองฝั่ง
• เลือกเหยื่อและระดับความลึก
• จับจังหวะปลากินเหยื่อและควบคุมความตึงของสาย
• เลือกเก็บหรือปล่อยปลาที่ตกได้

เกมยังอยู่ระหว่างการพัฒนา ข้อมูลปลาและจำนวนที่จับได้มีผลเฉพาะรอบการเล่นปัจจุบัน ยังไม่มีการบันทึกความคืบหน้าข้ามการเปิดเกม

รุ่นนี้เล่นแบบออฟไลน์ ไม่มีบัญชีผู้ใช้ โฆษณา หรือการซื้อภายในแอป
