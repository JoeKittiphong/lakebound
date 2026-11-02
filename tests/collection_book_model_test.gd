extends SceneTree
var failures := 0
var checks := 0
var output := "res://exports/book-model-qa"
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 if not ok: failures += 1
func settle() -> void:
 for frame in 5: await process_frame
func capture(name: String) -> void:
 await settle()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func tap(control: Control) -> void:
 var event := InputEventScreenTouch.new()
 event.index = 5
 event.position = control.get_global_rect().get_center()
 event.pressed = true
 root.push_input(event,true)
 event = event.duplicate()
 event.pressed = false
 root.push_input(event,true)
 await settle()
func run() -> void:
 DirAccess.make_dir_recursive_absolute(output)
 var scene = load("res://features/collection/collection_book_preview.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 await settle()
 var animation: AnimationPlayer = scene.animation
 var model: Node3D = scene.get_node("Preview/Viewport/Stage/Book")
 var skeleton: Skeleton3D = model.find_child("Skeleton3D",true,false)
 expect(skeleton != null, "GLB imports a skeleton")
 expect(skeleton.get_bone_count() == 12, "twelve authored hinge/curl bones import")
 var game_mesh: MeshInstance3D = model.find_child("CollectionBook_Mesh",true,false)
 expect(game_mesh != null and game_mesh.mesh.get_faces().size() / 3 == 614, "complete imported book remains 614 triangles")
 expect(game_mesh.mesh.get_surface_count() == 1, "imported book uses one material surface")
 expect(animation.has_animation("OpenBook") and animation.has_animation("TurnPage"), "both independent animation clips import")
 expect(is_equal_approx(animation.get_animation("OpenBook").length,0.6), "book opening lasts 0.6 seconds")
 expect(is_equal_approx(animation.get_animation("TurnPage").length,0.8), "page turn lasts 0.8 seconds")
 expect(animation.get_animation("OpenBook").loop_mode == Animation.LOOP_NONE and animation.get_animation("TurnPage").loop_mode == Animation.LOOP_NONE, "transition clips do not loop")
 expect(scene.state == "closed" and scene.get_node("Actions/Next").disabled, "closed book cannot turn a page")
 var front := skeleton.find_bone("FrontCover")
 var page := skeleton.find_bone("PageRoot")
 var closed_pose := skeleton.get_bone_pose_rotation(front)
 await capture("godot-closed")
 await tap(scene.get_node("Actions/Open"))
 expect(scene.state == "busy" and scene.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "touch opens book and enables viewport updates")
 expect(scene.get_node("Actions/Next").disabled and scene.get_node("Actions/Close").disabled, "transition guards repeated navigation")
 await create_timer(0.75).timeout
 expect(scene.state == "open", "natural opening completes in open state")
 expect(closed_pose.angle_to(skeleton.get_bone_pose_rotation(front)) > 3.0, "front cover actually rotates through 180 degrees")
 expect(scene.viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS, "idle book does not continuously render")
 await capture("godot-open")
 var right_pose := skeleton.get_bone_pose_rotation(page)
 await tap(scene.get_node("Actions/Next"))
 await create_timer(0.18).timeout
 var curl := skeleton.find_bone("PageCurl04")
 expect(skeleton.get_bone_pose_rotation(curl).angle_to(Quaternion.IDENTITY) > 0.01, "turning page bends through curl joints")
 await capture("godot-page-turn")
 await create_timer(0.9).timeout
 expect(scene.state == "open" and right_pose.angle_to(skeleton.get_bone_pose_rotation(page)) > 3.0, "next-page transition settles across the spine")
 await tap(scene.get_node("Actions/Previous"))
 await create_timer(0.9).timeout
 expect(scene.state == "open" and right_pose.angle_to(skeleton.get_bone_pose_rotation(page)) < 0.01, "reverse turn returns to its original page pose")
 await tap(scene.get_node("Actions/Close"))
 await create_timer(0.75).timeout
 expect(scene.state == "closed" and closed_pose.angle_to(skeleton.get_bone_pose_rotation(front)) < 0.01, "reversing the opening clip closes the book")
 for size in [Vector2i(1280,720), Vector2i(1600,720), Vector2i(1024,768)]:
  root.size = size
  await settle()
  for button in scene.get_node("Actions").get_children():
   expect(root.get_visible_rect().encloses(button.get_global_rect()), "review controls fit " + str(size))
 expect(scene.viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS, "closing stops continuous viewport rendering")
 scene.free()
 current_scene = null
 print("BOOK MODEL RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
