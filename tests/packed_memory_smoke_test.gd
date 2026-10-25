extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var counts: Array[int] = []
 var node_counts: Array[int] = []
 var packed := load("res://features/gameplay/gameplay.tscn") as PackedScene
 for cycle in 4:
  var scene: Node3D = packed.instantiate()
  root.add_child(scene)
  current_scene = scene
  scene.get_node("FishingEffects").audio_enabled = false
  scene.get_node("FishingController").set_physics_process(false)
  for i in 3:
   await process_frame
  scene.queue_free()
  current_scene = null
  for i in 4:
   await process_frame
  counts.append(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
  node_counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
 var stable := counts[-1] <= counts[1] + 2 and node_counts[-1] <= node_counts[1]
 print("PACKED MEMORY COUNTS resources=", counts, " nodes=", node_counts)
 print("PACKED MEMORY RESULT: ", 0 if stable else 1, " failures")
 quit(0 if stable else 1)
