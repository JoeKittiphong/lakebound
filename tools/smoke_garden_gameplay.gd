extends SceneTree
## Bounded startup check for all six real gameplay scenes, with isolated QA data.
func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.save_path = "user://garden-smoke.cfg"
 profile.data = profile.defaults()
 var failures := 0
 for entry in RegionCatalog.MAPS:
  var game: Node3D = load(entry.scene).instantiate()
  root.add_child(game)
  current_scene = game
  game.get_node("FishingEffects").audio_enabled = false
  for frame in 35:
   await physics_frame
  var garden: Node3D = game.get_node_or_null("World/GardenDressing")
  var player: AnglerPlayer = game.get_node("Player")
  var ok: bool = garden!=null and int(garden.get_meta("plant_count",0))>=120 and player.is_on_floor()
  failures += int(not ok)
  print("PASS: " if ok else "FAIL: ","gameplay starts with garden and grounded player: ",entry.id)
  game.queue_free()
  for frame in 3:
   await process_frame
 print("GARDEN GAMEPLAY RESULT: 6 maps, ",failures," failures")
 quit(int(failures>0))
