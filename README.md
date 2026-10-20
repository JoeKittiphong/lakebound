# Lakebound

เกมตกปลา 3D สำหรับมือถือแนวนอน ใช้ Godot 4.7 (ตรวจ refactor ด้วย 4.7.2), Mobile renderer และ Jolt Physics

เปิด `project.godot` ใน Godot แล้ว Run Project: Loading → Menu → Gameplay

## โครงสร้างและจุดแก้ใน Editor

| สิ่งที่ต้องการแก้ | เปิดไฟล์ |
|---|---|
| ประกอบ session และกำหนด reference ข้ามระบบ | `features/gameplay/gameplay.tscn` |
| ฉากทะเลสาบ ท่าเรือ ต้นไม้ แสง collision | `world/pond/pond.tscn` |
| กติกาขอบเขตน้ำ/พื้นที่เดิน/การขึ้นปลา | `world/pond/default_pond.tres` |
| กล้องและ sensitivity/pitch/follow speed | `features/gameplay/camera_rig.tscn` |
| ตัวละครและความเร็วเดิน/สู้ปลา | `actors/player/player.tscn` |
| HUD และตำแหน่งปุ่ม | `features/fishing/fishing_hud.tscn` |
| หน้าผลจับปลาและ preview | `features/fishing/ui/catch_result.tscn` |
| joystick คุมคันและรอก | `features/fishing/ui/rod_control.tscn` |
| สายเบ็ด ทุ่น วงน้ำ เสียง | `features/fishing/fishing_effects.tscn` |
| ระยะเวลาเหวี่ยง ความเร็วรอก และค่าปรับเกม | `features/fishing/default_fishing_tuning.tres` |
| สมุดสะสมและการ์ดปลา | `features/collection/collection_panel.tscn`, `collection_row.tscn` |
| ชนิดปลา โมเดล ไอคอน และค่าปรับรายชนิด | `data/fish/*.tres` |

ฉากย่อยบันทึก node hierarchy และ layout ไว้ใน `.tscn` ให้แก้ก่อน Play ได้ ปลาแต่ละตัวเป็น `FishState` แบบ RefCounted; spawn เฉพาะ visual ที่ต้องแสดง

Resources เป็น configuration ที่แชร์ได้ หากต้องปรับต่างกันเฉพาะหนึ่ง instance ให้ Make Unique ใน Inspector หรือ `duplicate()` ก่อนแก้ระหว่าง runtime ขอบเขตใน PondDefinition เป็นพิกัดโลก; การย้ายสถานที่ต้องปรับ definition ให้ตรงด้วย

อ่านขอบเขตระบบและข้อควรรักษาที่ [docs/architecture.md](docs/architecture.md) และคำสั่งทดสอบที่ [tests/README.md](tests/README.md)

## Build Android

กำหนด runtime paths จากเครื่องที่ใช้ โดยตั้ง `LAKEBOUND_GODOT`, `JAVA_HOME`, `ANDROID_SDK_ROOT` และเลือก `GRADLE_USER_HOME` ได้ หรือส่ง arguments:

```powershell
./tools/build_release.ps1 -Godot <godot-console.exe> -JavaHome <jdk-folder> -AndroidSdk <sdk-folder>
```

version มาจาก `config/version` ใน `project.godot`; ตั้ง `version/name` ของ Android AAB preset ให้ตรงกัน script จะตรวจความตรงก่อนเข้าขั้น signing ชื่อ output เริ่มต้นเป็น `exports/android/lakebound-<version>-closed.aab`

คง signing directory และ upload key ของแอปเดิมไว้ สำหรับย้ายเครื่องให้คืน backup เดิมและส่ง `-SigningDirectory`; ห้ามสร้าง identity ทดแทนแอปที่อัปโหลดแล้ว

ตรวจ bundle ที่เลือกโดยอ่าน manifest จาก bundle เดียวกัน:

```powershell
python tools/verify_release.py <bundle.aab> --bundletool <bundletool.jar> --qa-dir exports/qa
```

ถ้าไม่มี bundletool ใช้ `--manifest <same-build-AndroidManifest.xml>` แทน ต้องเป็น manifest ของ build เดียวกัน ปรับ `--artwork-dir` และ `--report` ได้ เครื่องมือตรวจไฟล์ไม่แทนการทดสอบบน Android หรือการตรวจของ Google Play
