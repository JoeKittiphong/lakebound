extends "res://tests/competition_test.gd"
func run() -> void:
 var world: Node3D=load("res://tests/fixtures/match_avatar_compare.tscn").instantiate()
 root.add_child(world)
 world.get_node("Remote/Name").text="REMOTE"
 var local: Node3D=world.get_node("Local/Visual/AnglerModel")
 var remote: Node3D=world.get_node("Remote/Visual/AnglerModel")
 expect(local.global_basis.get_scale().is_equal_approx(remote.global_basis.get_scale()),"local and remote models have identical world scale")
 expect(local.get_node("Asset").global_basis.get_scale().is_equal_approx(remote.get_node("Asset").global_basis.get_scale()),"rendered imported assets have identical world scale")
 expect(world.get_node("Local/Visual/FishingRod/Joint1/Joint2/Joint3/Joint4/Joint5/Tip")!=null,"shared visual preserves local rod attachment path")
 for dimensions in [Vector2i(960,540),Vector2i(1600,720)]:
  root.size=dimensions
  for i in 5: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-competition/avatar-equal-%dx%d.png" % [dimensions.x,dimensions.y])
 world.queue_free()
 print("AVATAR VISUAL RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
