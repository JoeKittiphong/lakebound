extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 checks += 1
 if value:
  print("PASS: ", message)
 else:
  failures += 1
  push_error("FAIL: " + message)

func run() -> void:
 var config := ConfigFile.new()
 expect(config.load("res://export_presets.cfg") == OK, "export presets load")
 var found := {}
 for section in config.get_sections():
  if not config.has_section_key(section, "name"):
   continue
  var name: String = config.get_value(section, "name")
  var options := section + ".options"
  found[name] = true
  var excluded := str(config.get_value(section, "exclude_filter", ""))
  expect("river_manifest.json" in excluded and "river_props.glb" in excluded and "river_terrain.glb" in excluded, "authoring inputs excluded " + name)
  expect(not "river_props_foliage_atlas_512.png" in excluded and not "river_props_wetland_atlas_256.png" in excluded, "runtime textures retained " + name)
  if name == "Android AAB":
   expect(config.get_value(options, "architectures/armeabi-v7a") and config.get_value(options, "architectures/arm64-v8a"), "production AAB preserves both supported ARM architectures")
  if name == "Android APK Playtest":
   expect(config.get_value(options, "gradle_build/compress_native_libraries"), "universal playtest APK compresses native libraries")
   expect(config.get_value(options, "architectures/armeabi-v7a") and config.get_value(options, "architectures/arm64-v8a"), "universal playtest preserves old device support")
  if name == "Android APK Compact ARM64":
   expect(not config.get_value(options, "architectures/armeabi-v7a") and config.get_value(options, "architectures/arm64-v8a"), "compact preset includes ARM64 only")
   expect(config.get_value(options, "gradle_build/compress_native_libraries"), "compact APK enables native compression")
 expect(found.has("Android APK Compact ARM64"), "compact preset exists")
 for path in ["res://world/river/river_world.tscn", "res://features/gameplay/gameplay.tscn", "res://actors/player/angler_model.tscn"]:
  var packed := load(path) as PackedScene
  expect(packed != null and packed.can_instantiate(), "runtime scene intact " + path)
 print("EXPORT SIZE RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
