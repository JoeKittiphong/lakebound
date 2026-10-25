extends SceneTree

class CountingProfile extends AnglerProfile:
 var weight_queries := 0
 func box_weight() -> float:
  weight_queries += 1
  return super.box_weight()

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var game: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 game.economy_enabled = false
 root.add_child(game)
 game.set_process(false)
 game.get_node("FishingController").set_physics_process(false)
 game.get_node("PondEcosystem").set_physics_process(false)
 game.get_node("FishingEffects").audio_enabled = false
 var hud: FishingHUD = game.get_node("HUD/FishingHUD")
 hud.set_process(false)
 hud.get_node("SafeArea/FirstCatch").active = false
 var profile := CountingProfile.new()
 profile.data = profile.defaults()
 hud.controller.profile = profile
 var report: Array[Dictionary] = []
 var failures := 0
 var baseline := OS.get_cmdline_user_args().has("--baseline")
 for count in [0, 200]:
  profile.data.catches = []
  for index in count:
   profile.data.catches.append({"weight": 0.1})
  profile.changed.emit()
  for warmup in 100:
   hud._process(1.0 / 60.0)
  var samples: Array[float] = []
  profile.weight_queries = 0
  var tracker_before: int = hud._mission_hud.tracker_refreshes
  for repetition in 5:
   var start := Time.get_ticks_usec()
   for frame in 2000:
    hud._process(1.0 / 60.0)
   samples.append(float(Time.get_ticks_usec() - start) / 2000.0)
  samples.sort()
  report.append({"stored_fish": count, "median_hud_us": samples[2], "iterations": 10000, "box_weight_queries": profile.weight_queries})
  var tracker_updates: int = hud._mission_hud.tracker_refreshes - tracker_before
  report[-1]["mission_tracker_updates"] = tracker_updates
  if not baseline and tracker_updates != 0:
   failures += 1
   print("FAIL: unchanged HUD must not rebuild the mission tracker")
  if not baseline and profile.weight_queries != 0:
   failures += 1
   print("FAIL: unchanged HUD must not recalculate stored-fish weight")
  profile.weight_queries = 0
  tracker_before = hud._mission_hud.tracker_refreshes
  profile.changed.emit()
  for frame in 3:
   hud._process(1.0 / 60.0)
  if not baseline and hud._mission_hud.tracker_refreshes - tracker_before != 1:
   failures += 1
   print("FAIL: profile change must refresh mission tracker exactly once")
  if not baseline and profile.weight_queries != 1:
   failures += 1
   print("FAIL: a profile change must refresh the box exactly once")
 var output := OS.get_environment("LAKEBOUND_QA_DIR").get_base_dir()
 if not output.is_empty():
  var file := FileAccess.open(output.path_join("hud-performance.json"), FileAccess.WRITE)
  file.store_string(JSON.stringify(report, " "))
 print("HUD PERFORMANCE RESULT: ", JSON.stringify(report), " failures=", failures)
 var presenter := hud._mission_hud
 hud.controller.profile = null
 game.queue_free()
 await process_frame
 if profile.changed.is_connected(presenter._invalidate):
  failures += 1
  print("FAIL: HUD teardown must disconnect the persistent profile")
 profile.free()
 quit(failures)
