extends SceneTree
var failures := 0
var checks := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + message)
func _initialize() -> void:
 call_deferred("run")
func scan(path: String, characters: Dictionary) -> void:
 for filename in DirAccess.get_files_at(path):
  if filename.get_extension() not in ["gd","tscn","tres"]: continue
  var text := FileAccess.get_file_as_string(path.path_join(filename))
  expect(not text.contains(char(0xfffd)),"UTF-8 replacement character absent: " + filename)
  for index in text.length():
   var code := text.unicode_at(index)
   if code > 127 and not (code >= 0xe00 and code <= 0xe7f): characters[code] = true
 for folder in DirAccess.get_directories_at(path):
  scan(path.path_join(folder),characters)
func run() -> void:
 var font: Font = load("res://shared/ui/fonts/game_font.tres")
 var original: FontFile = load("res://shared/ui/fonts/noto_sans_thai.ttf")
 expect(not original.allow_system_fallback,"OS font fallback disabled")
 var characters := {}
 for path in ["res://features","res://shared","res://data","res://world","res://services","res://actors"]:
  scan(path,characters)
 var covered := font.get_supported_chars()
 var raw := original.get_supported_chars()
 for code in characters:
  expect(covered.contains(char(code)),"packaged glyph U+%04X" % code)
  if not covered.contains(char(code)): print("MISSING: U+%04X" % code)
 print("RAW THAI arrows/check: ",raw.contains("←")," / ",raw.contains("✓"))
 var canvas := Control.new()
 canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 canvas.theme=load("res://shared/ui/game_theme.tres")
 root.add_child(canvas)
 var bg := ColorRect.new()
 bg.color=Color("102e3d")
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 canvas.add_child(bg)
 var sample := Label.new()
 sample.position=Vector2(40,40)
 sample.size=Vector2(1150,600)
 sample.add_theme_font_size_override("font_size",32)
 sample.text="Lakebound - Web icons\nลูกศรควบคุม: ← ↑ → ↓ ↗\nสูตรเหยื่อ: [←] → ←   ✓ ✓ ✓\nจุดบนแผนที่: ▲ ▼ ◆ ○ ●\nปุ่ม: ‹ ย้อนกลับ   ถัดไป ›   × ปิด   − ย่อ\nข้อความไทย · จุดคั่น • รอปลา… 2–7 ครั้ง\nเต็มหลอด ✓ • รอปลาเข้าถึงเหยื่อ\nยังไม่มีปลาที่สนใจ • โยกสูตรใหม่"
 canvas.add_child(sample)
 root.size=Vector2i(1280,720)
 for frame in 6: await process_frame
 if not output.is_empty() and DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.path_join("web_icon_sheet.png"))
 print("WEB ICONS: %d checks, %d failures" % [checks,failures])
 quit(0 if failures==0 else 1)
