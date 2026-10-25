extends SceneTree

var report: Array[Dictionary] = []

func _initialize() -> void:
 call_deferred("run")

func sample(label: String) -> void:
 for frame in 90:
  await process_frame
 var cpu: Array[float] = []
 var draws: Array[int] = []
 var triangles: Array[int] = []
 for frame in 120:
  await RenderingServer.frame_post_draw
  cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
  draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
  triangles.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
 cpu.sort()
 draws.sort()
 triangles.sort()
 report.append({"scenario": label, "median_process_ms": cpu[60], "median_draw_calls": draws[60], "median_primitives": triangles[60], "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))})

func run() -> void:
 root.size = Vector2i(1280, 720)
 root.get_node("FishCollection").recording_enabled = false
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 var game: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(game)
 current_scene = game
 game.get_node("FishingEffects").audio_enabled = false
 var fishing: FishingController = game.get_node("FishingController")
 var pond: PondEcosystem = game.get_node("PondEcosystem")
 fishing.set_physics_process(false)
 pond.set_physics_process(false)
 pond.reset_population(4207)
 var hud: FishingHUD = game.get_node("HUD/FishingHUD")
 hud.get_node("SafeArea/FirstCatch").active = false
 hud.get_node("SafeArea/FirstCatch").hide()
 await sample("ready")
 fishing.active_fish = pond.fish[0]
 fishing.fight.update_zones(fishing.active_fish)
 fishing.tension = (fishing.yellow_start + fishing.red_start) * 0.5
 fishing._change_state(FishingController.State.FIGHT)
 await sample("fight")
 var output := OS.get_environment("LAKEBOUND_QA_DIR").get_base_dir()
 var file := FileAccess.open(output.path_join("frame-performance.json"), FileAccess.WRITE)
 file.store_string(JSON.stringify(report, " "))
 print("FRAME PERFORMANCE RESULT: ", JSON.stringify(report))
 game.queue_free()
 await process_frame
 await process_frame
 quit()
