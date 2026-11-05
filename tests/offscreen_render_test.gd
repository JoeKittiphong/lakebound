extends SceneTree
var failures := 0
var results: Array = []
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
 print("PASS: " if ok else "FAIL: ", label)
 failures += int(not ok)
func sample(label: String) -> void:
 for i in 15: await process_frame
 if DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 results.append({"scenario":label,"draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
func run() -> void:
 var batch = load("res://world/rainforest_lake/foliage_batch.gd").new()
 batch.authored_mesh = BoxMesh.new()
 batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 batch.visibility_range_end = 75
 for i in 40:
  batch.authored_transforms.append(Transform3D(Basis.IDENTITY,Vector3(i*3,0,0)))
  batch.authored_colors.append(Color(float(i)/40,0.5,0.2))
 root.add_child(batch)
 var reference := MultiMesh.new()
 reference.transform_format = MultiMesh.TRANSFORM_3D
 reference.use_colors = true
 reference.mesh = batch.authored_mesh
 reference.instance_count = 40
 for i in 40: reference.set_instance_color(i,batch.authored_colors[i])
 expect(batch._partitions.size() > 1,"large foliage batch splits into spatial groups")
 var count := 0
 var seen := {}
 for part in batch._partitions:
  expect(part.cast_shadow == batch.cast_shadow and part.visibility_range_end == 75,"partition preserves shadows and distance")
  for i in part.multimesh.instance_count:
   var x: float = part.multimesh.get_instance_transform(i).origin.x
   expect(not seen.has(x),"instance preserved exactly once")
   seen[x] = true
   var original := roundi(x/3)
   expect(part.multimesh.get_instance_color(i).is_equal_approx(reference.get_instance_color(original)),"instance color matches unpartitioned GPU encoding")
   count += 1
 expect(count == 40,"all foliage instances retained")
 if DisplayServer.get_name() != "headless":
  var batch_camera := Camera3D.new()
  root.add_child(batch_camera)
  batch_camera.position = Vector3(0,0,10)
  batch_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
  batch_camera.size = 10
  batch_camera.make_current()
  await sample("foliage_partitioned")
  root.remove_child(batch)
  batch.minimum_partition_instances = 1000
  root.add_child(batch)
  await sample("foliage_unpartitioned")
  expect(results[0].primitives < results[1].primitives,"edge view submits fewer foliage primitives")
  batch_camera.free()
  root.remove_child(batch)
  batch.minimum_partition_instances = 24
  root.add_child(batch)
 root.remove_child(batch)
 root.add_child(batch)
 expect(batch._partitions.size() == 5,"reenter does not duplicate partitions")
 batch.free()
 root.get_node("FishCollection").recording_enabled=false
 var game = load("res://features/gameplay/gameplay.tscn").instantiate()
 game.economy_enabled=false
 root.add_child(game); current_scene=game
 game.get_node("FishingEffects").audio_enabled=false
 var effects = game.get_node("FishingEffects")
 var camera := Camera3D.new()
 game.add_child(camera)
 camera.global_position=Vector3(0,4,0)
 camera.far=100
 camera.look_at(Vector3(0,4,-10))
 var planes: Array[Plane] = camera.get_frustum()
 expect(effects._fish_in_view(Vector3(0,4,-10),planes),"fish ahead remains visible")
 expect(not effects._fish_in_view(Vector3(0,4,10),planes),"fish behind camera rejected")
 expect(not effects._fish_in_view(Vector3(100,4,-10),planes),"fish beyond side plane rejected")
 game.pond.set_physics_process(false)
 game.fishing.set_physics_process(false)
 for fish in game.pond.fish: fish.position.y = 12
 camera.make_current()
 camera.global_position = game.player.global_position + Vector3(0,4,0)
 camera.look_at(camera.global_position + Vector3.FORWARD)
 var rear = game.pond.fish[0]
 rear.position = Vector3(camera.global_position.x,1,camera.global_position.z+10)
 effects._update_fish_visuals()
 expect(effects._visible_candidates.is_empty(),"offscreen nearby fish uses no visual slot")
 camera.rotate_y(PI)
 effects._update_fish_visuals()
 expect(effects._visible_candidates.has(rear),"turning camera restores nearby fish visual")
 camera.rotate_y(PI)
 game.fishing.active_fish = rear
 effects._update_fish_visuals()
 expect(effects._visible_candidates.has(rear),"hooked fish remains available outside frustum")
 game.fishing.active_fish = null
 camera.free()
 game.camera_rig.get_node("Camera3D").make_current()
 await sample("gameplay_before")
 var panel = game.hud.get_node("TacklePanel")
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults()
 panel.bind(profile,game.fishing,game.pond,game.get_node("CommerceGateway"))
 panel.open()
 expect(root.disable_3d,"shop suppresses main world rendering")
 expect(not panel.get_node("Shop/%Shelf").viewport.disable_3d,"shop viewport still renders")
 await sample("shop_optimized")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../output/thermal-qa/shop-culling.png")
 root.disable_3d=false
 await sample("shop_forced_background")
 root.disable_3d=true
 panel.close()
 expect(not root.disable_3d,"closing shop restores world rendering")
 await sample("gameplay_restored")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../output/thermal-qa/world-restored.png")
 panel.open_category(3)
 panel.open_category(2)
 panel.close()
 expect(not root.disable_3d,"category changes preserve original rendering state")
 root.disable_3d = true
 panel.open(); panel.close()
 expect(root.disable_3d,"preexisting disabled viewport state is preserved")
 root.disable_3d = false
 if not results.is_empty():
  var optimized: Dictionary = results.filter(func(value):return value.scenario == "shop_optimized")[0]
  var background: Dictionary = results.filter(func(value):return value.scenario == "shop_forced_background")[0]
  expect(optimized.draws < background.draws / 2,"shop removes at least half of draw calls")
  print("OFFSCREEN METRICS: ", JSON.stringify(results))
  var file := FileAccess.open("res://../output/thermal-qa/offscreen-render.json",FileAccess.WRITE)
  file.store_string(JSON.stringify(results,"  "))
 panel.open()
 game.queue_free(); await process_frame
 expect(not root.disable_3d,"leaving scene with shop open restores viewport")
 print("OFFSCREEN RESULT: ",failures," failures")
 quit(failures)
