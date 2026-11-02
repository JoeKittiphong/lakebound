extends SceneTree
var checks:=0
var failures:=0
var collisions:Array=[]
func _initialize() -> void:call_deferred("run")
func expect(ok:bool,message:String)->void:
 checks+=1
 if not ok:
  failures+=1
  push_error("FAIL: "+message)
func mesh_nodes(node:Node)->Array[MeshInstance3D]:
 var result:Array[MeshInstance3D]=[]
 if node is MeshInstance3D:result.append(node)
 for child in node.get_children():result.append_array(mesh_nodes(child))
 return result
func hits(rod:DetailedFishingRod)->Array:
 var a:Vector3=rod.ribbon.control_points[0]
 var b:Vector3=rod.guide_points[0]
 # Start outside the roller/contact itself; check the free line span after it.
 a=a.move_toward(b,.003)
 var names:Array=[]
 for node in mesh_nodes(rod.held_reel.get_node("Model")):
  var points:=node.mesh.get_faces()
  var local_a:=node.to_local(a)
  var local_b:=node.to_local(b)
  for i in range(0,points.size(),3):
   var point:Variant=Geometry3D.segment_intersects_triangle(local_a,local_b,points[i],points[i+1],points[i+2])
   if point!=null:
    names.append(str(node.name))
    break
 return names
func run()->void:
 root.get_node("FishCollection").recording_enabled=false
 var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(1,1,3);camera.current=true
 var seen:Dictionary={}
 var pairs:=0
 for item in TackleCatalog.ITEMS:
  if item.kind!="rod":continue
  var rod:DetailedFishingRod=item.model_scene.instantiate();root.add_child(rod)
  if seen.has(rod.rod_id):rod.free();continue
  seen[rod.rod_id]=true
  var tested:Dictionary={}
  for entry in TackleCatalog.ITEMS:
   if entry.kind!="reel" or not EquipmentFit.compatible(item,entry) or tested.has(entry.model_scene):continue
   tested[entry.model_scene]=true;pairs+=1
   rod.set_held_reel(entry.model_scene)
   for phase in [0.0,.07,.23,.51,.83]:
    for fill in [.15,.55,1.0]:
     rod.held_reel.turns=phase
     rod.held_reel.advance(0,0,0,fill)
     rod.set_load(.8,0)
     rod.update_guides()
     expect(rod.ribbon.endpoint_error<.00001,"guide line endpoints remain exact during reel motion")
     expect(rod.held_reel.get_node("ReelFoot").global_position.distance_to(rod.get_node("ReelMount").global_position)<.00001,"reel foot stays fixed while winding")
     var names:=hits(rod)
     expect(names.is_empty(),"outgoing line clears reel body %s/%s phase %.2f fill %.2f hits %s" % [rod.rod_id,entry.reel_family,phase,fill,names])
     if not names.is_empty():collisions.append({"rod":rod.rod_id,"reel":rod.held_reel.reel_id,"phase":phase,"fill":fill,"parts":names})
     if entry.reel_family in ["spinning","low","round"]:
      expect(rod.feed_ribbon.visible and rod.feed_ribbon.endpoint_error<.00001,"spool-to-roller/levelwind line is present")
  rod.free()
 var file:=FileAccess.open("res://../output/guide-line-fit-v01/reel_exit_collisions.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"pairs":pairs,"checks":checks,"failures":failures,"collisions":collisions},"  "))
 print("REEL LINE EXIT: %d pairs, %d checks, %d failures" % [pairs,checks,failures])
 quit(0 if failures==0 else 1)
