extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool,label: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  push_error("FAIL: "+label)
func run() -> void:
 root.get_node("FishCollection").recording_enabled=false
 var paths: Array[String]=["res://world/river/river_world.tscn","res://world/pond/water_interactions.tscn"]
 for map_id in ["river","lotus_marsh","forest_stream","wild_reservoir","mangrove_estuary","coral_coast"]:
  paths.append("res://world/river/garden_dressing.tscn" if map_id=="river" else "res://world/regions/%s/garden_dressing.tscn"%map_id)
 for path in paths:
  var first: PackedScene=load(path)
  for cycle in 2:
   var packed: PackedScene=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REPLACE)
   var scene=packed.instantiate()
   root.add_child(scene)
   for frame in 2: await process_frame
   for node in scene.find_children("*","MultiMeshInstance3D",true,false):
    if node.get_script()==null: continue
    expect(node.multimesh!=null,"GPU batch rebuilt: "+str(node.name))
    expect(node.multimesh.instance_count==node.authored_transforms.size(),"instance count survives reload")
    if node.has_meta("plant_count"): expect(node.multimesh.instance_count==int(node.get_meta("plant_count")),"authored plant budget unchanged")
   scene.queue_free()
   await process_frame
 print("SAFE MULTIMESH RELOAD: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
