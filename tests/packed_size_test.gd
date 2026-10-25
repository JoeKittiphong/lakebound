extends SceneTree
var checks := 0
var failures := 0

func expect(value: bool, message: String) -> void:
 checks += 1
 if value:
  print("PASS: ", message)
 else:
  failures += 1
  push_error("FAIL: " + message)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 for source in ["river_props.glb", "river_terrain.glb", "foliage_atlas_512.png", "river_terrain_foliage_atlas_512.png", "wetland_atlas_256.png", "river_terrain_wetland_atlas_256.png"]:
  expect(not ResourceLoader.exists("res://assets/environment/river/" + source), "unneeded source excluded " + source)
 expect(not FileAccess.file_exists("res://assets/environment/river/river_manifest.json"), "authoring manifest absent from exported pack")
 for source in ["river_props_foliage_atlas_512.png", "river_props_wetland_atlas_256.png"]:
  expect(ResourceLoader.exists("res://assets/environment/river/" + source), "runtime material texture retained " + source)
 for path in ["res://world/river/river_world.tscn", "res://features/gameplay/gameplay.tscn", "res://actors/player/angler_model.tscn"]:
  var packed := load(path) as PackedScene
  expect(packed != null and packed.can_instantiate(), "exported scene intact " + path)
 var catalog := load("res://data/fish/fish_catalog.gd")
 expect(catalog.SPECIES.size() == 16, "all sixteen fish species retained")
 for species in catalog.SPECIES:
  expect(species.model_scene != null and species.model_scene.can_instantiate(), "exported fish model retained " + String(species.id))
 print("PACKED SIZE RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
