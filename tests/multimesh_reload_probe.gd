extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for path in ["res://world/river/garden_dressing.tscn","res://world/river/river_world.tscn"]:
  print("FIRST ",path)
  var original=ResourceLoader.load(path)
  print("RELOAD ",path)
  var reloaded=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REPLACE)
  print("RELOADED ",path)
 quit()
