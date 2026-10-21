extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
 if not ok:
  errors+=1
  push_error("FAIL: "+message)
 else:print("PASS: ",message)
func run() -> void:
 root.size=Vector2i(1440,900)
 var world=load("res://world/river/river_world.tscn").instantiate()
 root.add_child(world)
 current_scene=world
 var env: Environment=world.get_node("WorldEnvironment").environment
 check(env.sky.sky_material is PanoramaSkyMaterial and env.sky.sky_material.panorama.get_size()==Vector2(512,256),"512x256 panorama is assigned to the production world")
 check(env.sky.radiance_size==2 and env.sky.process_mode==1 and env.fog_sky_affect<.2,"small static sky cache and visible cloud background")
 var outer=world.get_node("OffMapSurroundings")
 var total:=0
 var geometry_ok:=true
 var seam_ok:=true
 var up_ok:=true
 var extent:=0.0
 var background_bytes:=FileAccess.get_file_as_bytes("res://assets/environment/river/sky_panorama_512.jpg").size()
 for tile in outer.get_children():
  var mesh:Mesh=tile.mesh
  var tris:=mesh.get_faces().size()/3
  total+=tris
  geometry_ok=geometry_ok and tris<=500 and tile.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  background_bytes+=FileAccess.get_file_as_bytes(mesh.resource_path).size()
  var arrays:=mesh.surface_get_arrays(0)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  for i in vertices.size():
   var p:=vertices[i]
   var edge:=maxf(absf(p.x),absf(p.z))
   extent=maxf(extent,edge)
   up_ok=up_ok and normals[i].y>0
   if absf(edge-240)<.01:
    seam_ok=seam_ok and absf(p.y-world.definition.ground_height(Vector2(p.x,p.z)))<.001
 check(outer.get_child_count()==16 and total==2880 and geometry_ok,"sixteen compressed outer patches, 180 triangles each, no shadows")
 check(seam_ok and up_ok,"all inner-edge vertices meet the original terrain and faces point upward")
 check(extent>1100 and world.get_node("RiverWater").mesh.size.x>=3000,"distant ground and water extend beyond the playable camera range")
 check(outer.find_children("*","CollisionObject3D",true,false).is_empty(),"background adds no collision or gameplay barriers")
 check(background_bytes<70000,"sky JPEG and all new terrain meshes total "+str(background_bytes)+" bytes")
 check(world.get_node("TerrainTiles").get_child_count()==225 and world.get_node("AquaticHabitats").get_child_count()==470,"playable terrain and dense flora are preserved")
 var camera:=Camera3D.new()
 camera.far=1000
 world.add_child(camera)
 camera.make_current()
 var c:float=world.definition.center_at(-116)
 var shots:=[{"name":"upstream","from":Vector3(c,4,-116),"to":Vector3(c,8,-500)},
 {"name":"downstream","from":Vector3(10,3,108),"to":Vector3(10,7,500)},
 {"name":"sky","from":Vector3(-90,6,40),"to":Vector3(0,75,-90)},
 {"name":"overview","from":Vector3(0,155,220),"to":Vector3(0,0,-25)}]
 for shot in shots:
  camera.position=shot.from
  camera.look_at(shot.to)
  for i in 20:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-river/background-"+shot.name+".png")
 print("BACKGROUND RESULT: ",errors," failures")
 world.queue_free()
 for i in 3:await process_frame
 quit(errors)

