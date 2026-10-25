extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1
 print("PASS: " if ok else "FAIL: ",label)
func shot(camera: Camera3D,point: Vector3,offset: Vector3,label: String) -> void:
 if DisplayServer.get_name()=="headless":return
 camera.global_position=point+offset;camera.look_at(point)
 for frame in 5:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("rocks_map_"+label+".png"))
func run() -> void:
 root.size=Vector2i(1400,900)
 var world: Node3D=load("res://world/river/river_world.tscn").instantiate()
 root.add_child(world);current_scene=world
 var definition: RiverDefinition=world.definition
 for frame in 15:await physics_frame
 expect(not world.has_node("Rocks"),"legacy rock container removed from map")
 var legacy_count:=0
 for node in world.find_children("*","Node3D",true,false):
  if node.scene_file_path.ends_with("r04_rock_cluster.tscn") or node.scene_file_path.ends_with("riv05_shore_rock_ledge.tscn") or node.scene_file_path.ends_with("riv04_ford_pebble_group.tscn"):legacy_count+=1
 expect(legacy_count==0,"no legacy boulders, ledges or ford pebble instances")
 var dressing: Node3D=world.get_node("RockLandscaping")
 var used:={}
 var placed:=0
 for zone in dressing.get_children():
  expect(zone.get_child_count()==38,"38 authored rocks in "+zone.name)
  var used_here:={}
  for rock: Node3D in zone.get_children():
   placed+=1
   var p:=Vector2(rock.global_position.x,rock.global_position.z)
   var depth:=definition.water_depth_at(p)
   var radius: float=rock.get_meta("footprint_radius")
   used[rock.scene_file_path]=true;used_here[rock.scene_file_path]=true
   expect((depth==0 if zone.name=="Land" else depth<=.15 if zone.name=="Shore" else depth>=.15 and depth<=1.4 if zone.name=="Shallow" else depth>=3),"correct habitat "+rock.name)
   expect(absf(p.y-definition.bridge_z)>13+radius and absf(p.y-definition.ford_z)>13+radius,"crossing clearance "+rock.name)
   expect(p.distance_to(Vector2(-69.52561,42))>13+radius and p.distance_to(Vector2(-64,35))>13+radius and p.distance_to(Vector2(96.68943,24))>17+radius,"spawn, boat and jetty clearance "+rock.name)
   expect(absf(p.x-definition.center_at(p.y))>12+radius,"central boat corridor "+rock.name)
   expect(rock is StaticBody3D and rock.get_node("CollisionShape3D").shape!=null,"collision retained "+rock.name)
  expect(used_here.size()==19,"all 19 models used in "+zone.name)
 expect(placed==152 and used.size()==19,"all new rock models placed in map")
 var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.far=800
 for zone_name in ["Land","Shore","Shallow","Deep"]:
  var zone:=dressing.get_node(zone_name)
  var rock: Node3D=zone.get_child(14 if zone_name!="Deep" else 9)
  var focus:=rock.global_position+Vector3.UP
  if zone_name=="Deep":
   # Underwater view of the actual deep riverbed; surface stays enabled.
   await shot(camera,focus,Vector3(7,3,10),zone_name.to_lower())
  else:await shot(camera,focus,Vector3(-9,7,12),zone_name.to_lower())
 await shot(camera,Vector3(-65,0,43),Vector3(2,5,12),"spawn")
 await shot(camera,Vector3(0,0,0),Vector3(0,190,245),"overview")
 world.queue_free();await process_frame
 print("ROCK LANDSCAPING RESULT: ",checks," checks, ",failures," failures")
 quit(int(failures>0))
