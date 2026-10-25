extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:
 call_deferred("run")
func expect(ok: bool,label: String) -> void:
 checks+=1
 print("PASS: " if ok else "FAIL: ",label)
 failures+=int(not ok)
func run() -> void:
 root.size=Vector2i(1400,1000)
 var scene: Node3D=load("res://world/river/props/reference_rocks_preview.tscn").instantiate()
 root.add_child(scene)
 current_scene=scene
 for i in 8:await physics_frame
 var textures:={}
 var total:=0
 for i in range(1,8):
  var rock: StaticBody3D=scene.get_node("Rock%02d"%i)
  var body: MeshInstance3D=rock.get_node("Visual")
  var material:=body.get_active_material(0) as StandardMaterial3D
  var count: int=body.mesh.surface_get_array_index_len(0)/3
  total+=count
  expect(count>=200 and count<=500,"mobile triangle budget for rock %02d: %d"%[i,count])
  expect(body.mesh.get_surface_count()==1 and material.albedo_texture!=null,"single textured surface on rock %02d"%i)
  expect(material.normal_enabled and material.normal_texture!=null,"retained fine surface normal on rock %02d"%i)
  var arrays: Array=body.mesh.surface_get_arrays(0)
  expect(arrays[Mesh.ARRAY_TEX_UV]!=null and not arrays[Mesh.ARRAY_TEX_UV].is_empty(),"UVs survive on rock %02d"%i)
  textures[material.albedo_texture.resource_path]=true
  var hit:=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(rock.global_position+Vector3(0,4,0),rock.global_position-Vector3.UP))
  expect(not hit.is_empty() and hit.collider==rock,"convex collision works on rock %02d"%i)
 expect(textures.size()==1,"seven variants share one color atlas")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("reference_rocks_set.png"))
 scene.queue_free()
 await process_frame
 print("REFERENCE ROCKS RESULT: ",checks," checks, ",failures," failures, ",total," total triangles")
 quit(int(failures>0))
