extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var lab=load("res://lab.tscn").instantiate()
 root.add_child(lab)
 await process_frame
 lab._run()
 await create_timer(3).timeout
 var status: String=lab.get_node("Margin/Column/Status").text
 print(status)
 var ok: bool=status.contains("OPEN") and lab.peers[0].received>0 and lab.peers[1].received>0
 await RenderingServer.frame_post_draw
 var output:=ProjectSettings.globalize_path("res://").path_join("../test-results")
 DirAccess.make_dir_recursive_absolute(output)
 root.get_texture().get_image().save_png(output.path_join("native-lab.png"))
 lab.queue_free()
 await process_frame
 print("NATIVE VISUAL RESULT: ","PASS" if ok else "FAIL")
 quit(0 if ok else 1)
