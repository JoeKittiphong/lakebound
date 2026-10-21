extends SceneTree
var errors := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  errors += 1
  push_error("FAIL: " + message)
 else: print("PASS: ",message)
func run() -> void:
 root.size = Vector2i(1440,900)
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
 var habitats = world.get_node("AquaticHabitats")
 var counts := {"shallow":0,"deep":0,"emergent":0}
 var types: Dictionary = {}
 var geometry_ok := true
 var height_ok := true
 var floor_ok := true
 for batch in habitats.get_children():
  var habitat: String = batch.get_meta("habitat")
  counts[habitat] += batch.multimesh.instance_count
  types[batch.get_meta("source_asset")] = true
  var mesh: Mesh = batch.multimesh.mesh
  geometry_ok = geometry_ok and mesh.get_faces().size()/3 <= 500 and batch.visibility_range_end <= 100
  var max_y := mesh.get_aabb().end.y
  var min_y := mesh.get_aabb().position.y
  for i in batch.multimesh.instance_count:
   var t: Transform3D = batch.multimesh.get_instance_transform(i)
   var base: Vector3 = batch.position+t.origin
   var scale: float = t.basis.get_scale().y
   var top: float = base.y+max_y*scale
   height_ok = height_ok and (top > .0 if habitat=="emergent" else top < -.22)
   var q := PhysicsRayQueryParameters3D.create(Vector3(base.x,12,base.z),Vector3(base.x,-20,base.z),1)
   var hit := root.world_3d.direct_space_state.intersect_ray(q)
   floor_ok = floor_ok and not hit.is_empty() and base.y+min_y*scale <= float(hit.position.y)+.12
 check(types.size()==10,"ten distinct low-poly plant models are present")
 check(counts.shallow>1500 and counts.deep>7000 and counts.emergent>400,"dense habitat populations: " + str(counts))
 check(geometry_ok,"all plant models remain below 500 triangles with bounded visibility")
 check(height_ok,"submerged foliage stays underwater and marsh foliage grows above the surface")
 check(floor_ok,"plant bases are rooted in the actual triangulated ground")
 check(habitats.find_children("*","CollisionObject3D",true,false).is_empty(),"dense vegetation never blocks movement or fishing")
 check(habitats.get_child_count()<600,"9157 plants use fewer than 600 editable spatial render batches")
 check(game.get_node("PondEcosystem").fish.size()==112,"persistent fish population is preserved")
 var camera := Camera3D.new()
 camera.far=700
 game.add_child(camera)
 camera.make_current()
 game.get_node("HUD").visible=false
 var def: RiverDefinition=world.definition
 var z:=16.0
 var x:=def.center_at(z)-def.half_width_at(z)
 var shots := [{"name":"marsh","from":Vector3(x-3,4.5,z+10),"to":Vector3(x+4,.0,z)},
 {"name":"shallows","from":Vector3(x+3,3,z+5),"to":Vector3(x+8,-1,z)},
 {"name":"deep","from":Vector3(def.center_at(0),-9,8),"to":Vector3(def.center_at(0)+3,-11,0)}]
 for shot in shots:
  camera.position=shot.from
  camera.look_at(shot.to)
  for i in 20:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-river/dense-"+shot.name+".png")
  print("RENDER ",shot.name," primitives=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
 print("DENSE FLORA RESULT: ",errors," failures")
 game.queue_free()
 for i in 3: await process_frame
 quit(errors)


