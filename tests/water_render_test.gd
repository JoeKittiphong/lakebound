extends SceneTree

var failures := 0
const OUTPUT := "res://exports/qa-water"

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
 else:
  print("PASS: ", message)

func capture(label: String) -> void:
 for frame in 12:
  await process_frame
 await RenderingServer.frame_post_draw
 expect(root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png") == OK, label)

func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 root.size = Vector2i(1280, 720)
 root.get_node("FishCollection").recording_enabled = false
 # This depth comparison targets the authored lake fixture, not the river map.
 var scene: Node3D = load("res://tests/legacy_gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 var ecosystem = scene.get_node("PondEcosystem")
 var effects = scene.get_node("FishingEffects")
 ecosystem.set_physics_process(false)
 scene.get_node("FishingController").set_physics_process(false)
 scene.get_node("Player").set_physics_process(false)
 for fish in ecosystem.fish:
  fish.position.y = 12.0
 var depths := [0.15, 0.8, 1.8, 3.5, 5.5]
 for i in depths.size():
  var fish = ecosystem.fish[i]
  fish.position = Vector3(-4.0 + i * 2.0, depths[i], -11.0)
  fish.heading = PI * 0.5
 effects._update_fish_visuals()
 expect(effects.visual_pool.size() == 7, "fish pool remains bounded at seven")
 for i in 4:
  # The visual pool is sorted by distance, so identify the fish by its record.
  var matches = effects.visual_pool.filter(func(visual): return visual.visible and visual.record == ecosystem.fish[i])
  expect(matches.size() == 1, "fish visible at depth " + str(depths[i]))
  if matches.size() == 1:
   expect(is_equal_approx(matches[0].global_position.y, effects.water_height - depths[i]), "true fish depth " + str(depths[i]))
 expect(effects.visual_pool.filter(func(visual): return visual.visible and visual.record == ecosystem.fish[4]).is_empty(), "deep fish culled below visibility budget")
 expect(scene.get_node("World/Lake").mesh is PlaneMesh, "water is one single-sided plane")
 expect(scene.get_node("World/LakeBed").mesh != null, "authored lake bed loaded")
 await capture("gameplay")
 scene.get_node("HUD").hide()
 var camera: Camera3D = scene.get_node("CameraRig/Camera3D")
 camera.global_position = Vector3(0, 8, -1)
 camera.look_at(Vector3(0, -1.5, -12))
 await capture("depth-comparison")
 root.size = Vector2i(1600, 720)
 await capture("depth-wide")
 root.size = Vector2i(1280, 720)
 camera.global_position = Vector3(-9, 4, 5)
 camera.look_at(Vector3(-9, -1, -2))
 await capture("shore")
 print("WATER RESULT: ", failures, " failures")
 quit(failures)
