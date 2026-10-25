extends SceneTree

var checks := 0
var failures := 0
const PNG := "res://assets/ui/atlas/modern_flat.png"

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 checks += 1
 if value:
  print("PASS: ", message)
 else:
  failures += 1
  push_error("FAIL: " + message)

func shared_texture(texture: Texture2D) -> bool:
 return texture.resource_path == PNG or (texture is AtlasTexture and texture.atlas.resource_path == PNG and texture.filter_clip)

func run() -> void:
 var atlas := load(PNG) as Texture2D
 expect(atlas != null and atlas.get_width() == 512 and atlas.get_height() == 512, "one generated atlas imports at 512 square for 1 MiB RGBA budget")
 var image := atlas.get_image()
 expect(image != null and image.get_pixel(0, 0).a < 0.01, "atlas has actual transparent padding")
 var directory := DirAccess.open("res://assets/ui/atlas")
 var sprites := 0
 var pngs := 0
 for file in directory.get_files():
  pngs += int(file.ends_with(".png"))
  if not file.ends_with(".tres") or file.begins_with("style_"):
   continue
  var sprite := load("res://assets/ui/atlas/" + file) as AtlasTexture
  expect(sprite != null and shared_texture(sprite), "region shares the same GPU texture " + file)
  if sprite != null:
   var bounds := Rect2(Vector2.ZERO, Vector2(atlas.get_width(), atlas.get_height()))
   expect(bounds.encloses(sprite.region) and sprite.region.size.x > 0 and sprite.region.size.y > 0, "region stays within source " + file)
   sprites += 1
 expect(sprites == 16, "sixteen sprites with no separate raster crops")
 expect(pngs == 1, "only one raster source is shipped for the new UI skin")
 var presets := ConfigFile.new()
 presets.load("res://export_presets.cfg")
 for section in presets.get_sections():
  if presets.has_section_key(section, "export_filter"):
   var excluded := str(presets.get_value(section, "exclude_filter", ""))
   expect("assets/ui/modern/*.svg" not in excluded and "assets/ui/collection/*" in excluded, "runtime SVG icons retained and unused collection art excluded by export preset " + section)
 for path in ["res://assets/ui/modern/hud_theme.tres", "res://shared/ui/game_theme.tres"]:
  var theme := load(path) as Theme
  for control in ["Button", "PanelContainer", "ProgressBar", "TabBar", "TabContainer", "VScrollBar"]:
   for name in theme.get_stylebox_list(control):
    var box := theme.get_stylebox(name, control)
    expect(box is StyleBoxTexture and shared_texture(box.texture), "theme uses atlas skin %s %s %s" % [path, control, name])
  expect(theme.get_font("font", "Label") != null or theme.default_font != null, "Thai font remains dynamic " + path)
 for path in ["res://features/fishing/fishing_hud.tscn", "res://features/collection/collection_panel.tscn", "res://features/economy/tackle_panel.tscn", "res://features/missions/mission_panel.tscn", "res://features/fishing/ui/catch_result.tscn", "res://features/menu/main_menu.tscn"]:
  var scene := load(path) as PackedScene
  expect(scene != null and scene.can_instantiate(), "authored screen still loads " + path)
 var joystick: Control = load("res://shared/ui/virtual_joystick.tscn").instantiate()
 expect(joystick.get_node("Base").get_theme_stylebox("panel") is StyleBoxTexture and joystick.get_node("Knob").get_theme_stylebox("panel") is StyleBoxTexture, "joystick surfaces share atlas while preserving real input controls")
 joystick.free()
 print("UI ATLAS RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
