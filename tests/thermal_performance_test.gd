extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 failures += int(not ok)

func run() -> void:
 var world := Node3D.new()
 root.add_child(world)
 var start := Node3D.new()
 var end := Node3D.new()
 var camera := Camera3D.new()
 world.add_child(start); world.add_child(end); world.add_child(camera)
 end.position = Vector3(0, 1, 0)
 camera.position = Vector3(0, 0, 3)
 var ribbon = load("res://features/equipment/detailed/line_ribbon.gd").new()
 world.add_child(ribbon)
 ribbon.start_anchor = ribbon.get_path_to(start)
 ribbon.end_anchor = ribbon.get_path_to(end)
 ribbon.camera_path = ribbon.get_path_to(camera)
 ribbon.refresh()
 var original: Mesh = ribbon.mesh
 for i in 100: ribbon.refresh()
 expect(ribbon.mesh == original and ribbon.mesh_rebuilds == 1, "100 unchanged updates reuse one line mesh")
 end.position.x += 0.1
 ribbon.refresh()
 expect(ribbon.mesh != original and ribbon.endpoint_error == 0, "moving endpoint rebuilds line accurately")
 var before: int = ribbon.mesh_rebuilds
 camera.position.x += 0.5
 ribbon.refresh()
 expect(ribbon.mesh_rebuilds == before + 1, "camera movement updates facing ribbon")
 world.free()
 var results := []
 for resolution in [256, 128]:
  world = Node3D.new()
  var actor := Node3D.new()
  var surface := MeshInstance3D.new()
  surface.mesh = PlaneMesh.new()
  var mat := ShaderMaterial.new()
  mat.shader = load("res://world/water.gdshader")
  surface.material_override = mat
  world.add_child(actor); world.add_child(surface)
  var water = load("res://world/pond/water_interactions.tscn").instantiate()
  water.player = actor; water.water_surface = surface
  water.use_gpu_field = false; water.field_resolution = resolution
  world.add_child(water); root.add_child(world)
  water.set_process(false)
  for i in 12:
   water.emit_ripple(Vector3(float(i % 4) * 5, 0, float(i / 4) * 5))
  var samples: Array[float] = []
  for i in 30:
   water.clock = 0.5 + float(i % 8) * 0.1
   var t := Time.get_ticks_usec()
   water._update_field()
   if i >= 5: samples.append((Time.get_ticks_usec()-t)/1000.0)
  samples.sort()
  results.append({"resolution":resolution, "median_update_ms":samples[12]})
  expect(water.active_event_count == 12, "all ripple events retained at %d" % resolution)
  water.clock = 10
  water._update_field()
  expect(not water._field_was_active, "expired field stops at %d" % resolution)
  world.free()
 print("WATER CPU COMPARISON: ", JSON.stringify(results))
 var panel = load("res://features/fishing/ui/fish_storage_panel.tscn").instantiate()
 root.add_child(panel)
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 panel.bind(profile, null)
 panel.open()
 await create_timer(1.1).timeout
 expect(panel.viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS, "cooler stops continuous rendering after opening")
 panel.close()
 expect(panel.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "closing animation resumes rendering")
 await create_timer(1.1).timeout
 expect(not panel.visible and panel.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "closed cooler releases rendering")
 panel.queue_free()
 if DisplayServer.get_name() != "headless":
  root.get_node("FishCollection").recording_enabled = false
  var game = load("res://features/gameplay/gameplay.tscn").instantiate()
  game.economy_enabled = false
  game.get_node("WaterInteractions").field_resolution = 128
  game.get_node("WaterInteractions").field_update_interval = 0.1
  root.add_child(game)
  current_scene = game
  game.get_node("FishingEffects").audio_enabled = false
  root.scaling_3d_scale = game.web_3d_scale
  game._limit_web_shadows(game.get_node("World"))
  for dimensions in [Vector2i(1280,720), Vector2i(1600,720)]:
   root.size = dimensions
   for i in 20: await process_frame
   await RenderingServer.frame_post_draw
   var path := "res://../output/thermal-qa/gameplay-%dx%d.png" % [dimensions.x, dimensions.y]
   expect(root.get_texture().get_image().save_png(path) == OK, "web quality screenshot %s" % dimensions)
  game.queue_free()
  await process_frame
 print("THERMAL PERFORMANCE RESULT: ", failures, " failures")
 quit(failures)
