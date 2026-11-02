extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for path in ["res://world/river/garden_dressing.tscn","res://features/loading/cinematic/loading_jungle_dressing.tscn","res://world/pond/water_interactions.tscn","res://features/gameplay/gameplay.tscn"]:
  print("BEFORE LOAD ",path)
  var packed=load(path)
  print("BEFORE INSTANTIATE ",path)
  var node=packed.instantiate()
  print("AFTER INSTANTIATE ",path)
  node.free()
 print("DONE")
 quit()
