extends SceneTree
var errors := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  errors += 1
  push_error(message)
 else: print("PASS: ", message)
func run() -> void:
 root.size = Vector2i(1280,720)
 root.get_node("FishCollection").recording_enabled = false
 var game = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(game)
 current_scene = game
 game.get_node("FishingEffects").audio_enabled = false
 game.get_node("FishingController").set_physics_process(false)
 game.get_node("PondEcosystem").set_physics_process(false)
 game.get_node("Player").set_physics_process(false)
 for i in 5: await physics_frame
 var world = game.get_node("World")
 var counts := {"surface":0,"algae":0,"pads":0}
 var correct := true
 var surface_sample: Node3D
 var algae_sample: Node3D
 for prop in world.get_node("Aquatic").get_children():
  if not prop.has_meta("aquatic_layer"): continue
  var id: String = prop.get_meta("source_asset")
  var model: MeshInstance3D = prop.get_node("Model")
  var box := model.get_aabb()
  var top: float = prop.position.y + box.end.y * prop.scale.y
  var bottom: float = prop.position.y + box.position.y * prop.scale.y
  correct = correct and prop.find_children("*", "CollisionObject3D",true,false).is_empty()
  correct = correct and model.get_surface_override_material(0).cull_mode == BaseMaterial3D.CULL_DISABLED
  if id.begins_with("V04"):
   if surface_sample == null or absf(prop.position.z - 40) < absf(surface_sample.position.z - 40): surface_sample = prop
   counts.surface += 1
   correct = correct and bottom > -0.18 and bottom < -0.05
  else:
   correct = correct and top < -0.20
   if id.begins_with("V05"):
    if algae_sample == null or absf(prop.position.z - 40) < absf(algae_sample.position.z - 40): algae_sample = prop
    counts.algae += 1
    var p: Vector3 = prop.global_position
    var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, 10, p.z),Vector3(p.x,-20,p.z),1)
    var hit := root.world_3d.direct_space_state.intersect_ray(query)
    correct = correct and not hit.is_empty() and bottom <= float(hit.position.y) + .08
   else: counts.pads += 1
 check(correct,"plants have correct surface/submerged heights, double-sided materials and no blocking colliders")
 check(counts.surface >= 12 and counts.algae >= 30 and counts.pads >= 12,"all three habitat layers are authored: " + str(counts))
 check(game.get_node("PondEcosystem").fish.size()==112,"all persistent fish remain present")
 var camera := Camera3D.new()
 camera.far = 700
 game.add_child(camera)
 camera.make_current()
 game.get_node("HUD").visible = false
 camera.position = surface_sample.position + Vector3(-2.8,3.5,3.5)
 camera.look_at(surface_sample.position)
 for i in 20: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://exports/qa-river/aquatic-surface.png")
 camera.position = algae_sample.position + Vector3(1.6,.85,1.8)
 camera.look_at(algae_sample.position + Vector3(0,.35,0))
 for i in 10: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://exports/qa-river/aquatic-underwater.png")
 print("AQUATIC RESULT: ",errors," failures")
 game.queue_free()
 for i in 3: await process_frame
 quit(errors)
