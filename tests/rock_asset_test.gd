extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func expect(ok: bool,label: String) -> void:
 checks+=1
 print("PASS: " if ok else "FAIL: ",label)
 failures+=int(not ok)
func ticks(count: int) -> void:
 for i in count:await physics_frame
func run() -> void:
 root.size=Vector2i(1100,900)
 var scene: Node3D=load("res://world/river/props/rock_mobile_preview.tscn").instantiate()
 root.add_child(scene)
 current_scene=scene
 await ticks(5)
 var meshes:=scene.get_node("Rock/Visual").find_children("*","MeshInstance3D",true,false)
 expect(meshes.size()==1,"game rock exports as one mesh")
 var body: MeshInstance3D=meshes[0]
 expect(body.mesh.get_surface_count()==1,"one rock material / surface")
 expect(body.mesh.surface_get_array_index_len(0)/3==224,"evaluated Decimate silhouette exports at 224 triangles")
 var arrays: Array=body.mesh.surface_get_arrays(0)
 expect(arrays[Mesh.ARRAY_TEX_UV]!=null and not arrays[Mesh.ARRAY_TEX_UV].is_empty(),"rock has usable exported UVs")
 var mat:=body.get_active_material(0) as StandardMaterial3D
 expect(mat.albedo_texture!=null and mat.albedo_texture.get_width()==1024,"1024px stone albedo imports")
 expect(mat.normal_enabled and mat.normal_texture!=null,"OpenGL stone normal map imports enabled")
 var shape: ConvexPolygonShape3D=scene.get_node("Rock/CollisionShape3D").shape
 expect(shape.points.size()>=4 and shape.points.size()<=128,"simple editable convex collider")
 var hit:=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,4,0),Vector3(0,-1,0)))
 expect(not hit.is_empty() and hit.collider==scene.get_node("Rock") and hit.position.y>1,"physics ray hits rock surface")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("rock_game_ready.png"))
 var player: AnglerPlayer=load("res://actors/player/player.tscn").instantiate()
 scene.add_child(player)
 player.global_position=Vector3(0,.05,3)
 await ticks(15)
 Input.action_press("move_forward")
 await ticks(90)
 Input.action_release("move_forward")
 expect(player.global_position.z>.6 and player.global_position.z<2.2,"actual game player cannot walk through the rock")
 scene.queue_free()
 await process_frame
 print("ROCK ASSET RESULT: ",checks," checks, ",failures," failures")
 quit(int(failures>0))
