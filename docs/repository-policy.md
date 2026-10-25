# ไฟล์ที่เก็บใน GitHub

ตรวจวันที่ 25 ตุลาคม 2026 สำหรับโปรเจกต์ Godot `fishing-game/` และ repository
`JoeKittiphong/lakebound` เดิม (Public) ใช้ branch `main` เดิม ไม่เปลี่ยน visibility

## เก็บไว้

| ประเภท | เหตุผล |
|---|---|
| `.gd`, `.tscn`, `.tres`, `.res`, shader, `project.godot` | ซอร์สเกม ฉากที่แก้ใน Editor และข้อมูล configuration |
| `assets/`, `actors/`, `world/`, ภาพ/โมเดล/texture ที่ฉากใช้งาน | ต้องมีเพื่อ import และเปิดเกมจาก clone ใหม่ได้ |
| `.import`, `.uid` ที่อยู่คู่กับซอร์ส | ค่าการนำเข้าและ resource identity; ต่างจาก cache ใน `.godot/` |
| `export_presets.cfg` | build configuration ที่ไม่มีรหัสผ่านหรือ signing key |
| `tests/`, `tools/`, `docs/` | regression, เครื่องมือสร้าง asset/build และเหตุผลการออกแบบ |
| `shared/branding/icon-source.png`, `docs/play-store/feature-source.png` | แม้ไม่ใช่ runtime แต่ `tools/prepare_branding.py` ต้องใช้เพื่อสร้างภาพซ้ำ จึงเก็บไว้ |
| `.gitignore`, `.gitattributes`, `.editorconfig` | กติกา repository และรูปแบบไฟล์ร่วมกัน |

ไม่มีไฟล์เดี่ยวเกิน 100 MiB ในรายการที่ตรวจ จึงยังไม่เพิ่ม Git LFS; ไฟล์ใหญ่สุด
เป็นโมเดลประมาณ 12.8 MiB หากมี asset ใหญ่เพิ่มในอนาคต ให้พิจารณา LFS ก่อน commit
แทนการย้าย asset ที่ใช้งานออกจน clone เปิดเกมไม่ได้

## ไม่เก็บใน source repository

| ประเภท | ตำแหน่ง/ตัวอย่าง | วิธีเก็บแทน |
|---|---|---|
| Godot cache | `.godot/` | สร้างใหม่ด้วย Import |
| Android build/generated project | `android/` | ติดตั้ง Android build template บนเครื่อง build |
| ผล export และ QA screenshots/logs/profile | `exports/`, `*.apk`, `*.aab`, `*.apks`, `*.pck`, `*.log` | GitHub Releases หรือ artifact storage เมื่อมีการออก release |
| คีย์ลงนามและรหัสผ่าน | `signing/`, `.signing/`, `*.jks`, `*.keystore`, `*.dpapi`, `release-credentials.json` | backup ส่วนตัวที่มีการจำกัดสิทธิ์; ใช้คีย์เดิมของแอป |
| ข้อมูลเชื่อมบริการ | `.env*` ยกเว้น `.env.example`, service-account JSON, private keys | secret store ของเครื่องหรือ CI |
| เซฟผู้เล่น | `user_data/`, `angler_profile*.cfg`, `fish_collection*.cfg`, `first_catch_tutorial*.cfg` | ข้อมูล local; fixtures ให้สร้างจากโค้ดทดสอบ |
| tool/editor cache และ backup | `.venv/`, `node_modules/`, `.pytest_cache/`, `.vscode/`, `.idea/`, `*.tmp`, `*.bak`, `.blend1/.blend2` | สร้างใหม่หรือเก็บ local |

โฟลเดอร์งาน Blender/retopology, `assets-source/`, ภาพ concept และ export ขนาดใหญ่
ที่อยู่ **เหนือ project root** ไม่ได้รวมใน repository เกมนี้ เก็บไว้ใน workspace
เดิม ไม่มีการลบไฟล์ local เพื่อทำให้ repo เล็กลง ต้นฉบับที่จำเป็นต่อเครื่องมือบางตัว
อ้างอิงในเอกสารได้ แต่ไม่ใช่เงื่อนไขสำหรับเปิดเกมตามปกติ

## ตรวจซ้ำก่อน push

```powershell
python tools/audit_repository.py --report exports/repository-audit.json
git diff --cached --stat
git diff --cached --check
```

ตัวตรวจอ่านเฉพาะไฟล์ที่ Git จะนำขึ้น รวมไฟล์ที่ tracked อยู่แล้ว จึงไม่เข้าอ่าน
signing folder ที่ถูก ignore ตรวจชนิดไฟล์ต้องห้าม ขนาด และรูปแบบ token/private key
ที่รู้จักโดยไม่พิมพ์ค่าลับ การตรวจครั้งนี้ไม่พบ known-secret pattern ในซอร์สที่ตรวจ
และไม่พบชื่อไฟล์ key/credential ในรายชื่อ objects ของประวัติ Git ที่มีอยู่
ไม่ได้อ้างว่าเป็นการสแกนเนื้อหาประวัติทั้งหมด

ห้าม ignore `.res`, `.glb`, `.png`, `.import` หรือ `.uid` ทั้งหมดเพียงเพราะเป็น binary
หรือไฟล์ Godot เพราะทำให้ resource dependencies หายได้ กรณี startup 0.1.9 เป็น
ตัวอย่างที่ควรใช้ตรวจแพ็กที่ส่งออกจริงก่อนออก release

## ผลตรวจสำเนาซอร์สสำหรับ GitHub

สร้างสำเนาจากรายการ `git ls-files --cached --others --exclude-standard` เท่านั้น
โดยไม่คัดลอก `.godot/`, `.git/`, `android/`, `signing/` หรือ `exports/` แล้ว import
ใหม่ด้วย Godot 4.7.2 สำเร็จ (exit 0) ในวันที่ 25 ตุลาคม 2026

| ชุดตรวจจากสำเนาใหม่ | ผล |
|---|---|
| loading_flow | 0 failures |
| fishing_recovery | 64 checks, 0 failures |
| economy | 40 checks, 0 failures |
| regions_legacy_save | 7 checks, 0 failures |
| refactor_boundaries | 21 checks, 0 failures |

มี host root-certificate diagnostic และ warning ของ ObjectDB ตอนปิด loading test
จึงไม่ได้อ้างว่า log ไม่มี warning ไม่ใช่การรัน full suite หรือทดสอบ Android จริง
หลักฐาน local อยู่ใน `exports/github-clean-check/` ซึ่งไม่อยู่ใน source repository
