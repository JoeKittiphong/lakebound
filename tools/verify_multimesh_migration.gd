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
 if DisplayServer.get_name()=="headless":
  push_error("Use the GPU renderer for buffer validation")
  quit(1)
  return
 root.get_node("FishCollection").recording_enabled=false
 var report: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../output/multimesh-fix/before-data.json"))
 var total:=0
 for entry in report:
  var packed: PackedScene=load(entry.path)
  for cycle in 2:
   packed=ResourceLoader.load(entry.path,"",ResourceLoader.CACHE_MODE_REPLACE)
   var scene=packed.instantiate()
   root.add_child(scene)
   for frame in 2: await process_frame
   for record in entry.batches:
    var node: MultiMeshInstance3D=scene.get_node(record.node)
    var transforms: Array=str_to_var(record.transforms)
    var colors: Array=str_to_var(record.colors)
    expect(node.multimesh!=null and node.multimesh.instance_count==int(record.count),"batch count: "+str(record.node))
    expect(node.authored_transforms.size()==int(record.count),"saved CPU transforms")
    for i in transforms.size():
     expect(node.multimesh.get_instance_transform(i).is_equal_approx(transforms[i]),"original plant transform "+str(i))
     expect(node.multimesh.get_instance_color(i).is_equal_approx(colors[i]),"original plant color "+str(i))
    if cycle==0:total+=int(record.count)
   scene.queue_free()
   await process_frame
 # Replacing the water template must also leave format setters safe.
 var water: PackedScene=load("res://world/pond/water_interactions.tscn")
 water=ResourceLoader.load("res://world/pond/water_interactions.tscn","",ResourceLoader.CACHE_MODE_REPLACE)
 expect(water!=null,"water reload succeeds")
 print("MULTIMESH RELOAD: ",checks," checks, ",failures," failures; original instances preserved=",total)
 quit(0 if failures==0 else 1)
