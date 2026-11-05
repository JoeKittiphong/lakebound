extends "res://tests/competition_test.gd"
func run() -> void:
 root.get_node("Competition").enabled=false
 root.get_node("RankingOnline").enabled=false
 var panel: Control=load("res://features/auth/login_panel.tscn").instantiate()
 root.add_child(panel)
 panel.open()
 for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(960,540)]:
  root.size=dimensions
  for i in 4: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-competition/google-login-%dx%d.png" % [dimensions.x,dimensions.y])
  expect(panel.get_node("%Google").get_global_rect().end.x<=root.get_visible_rect().size.x,"Google button fits "+str(dimensions))
  expect(panel.get_node("%Offline").get_global_rect().end.y<=root.get_visible_rect().size.y,"offline action fits "+str(dimensions))
 var auth: Node=root.get_node("AccountAuth")
 auth.needs_name=true
 auth.account_ready=true
 auth.email="qa@example.test"
 auth.status="ตั้งชื่อที่ต้องการใช้ในเกม"
 panel.render()
 for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(960,540)]:
  root.size=dimensions
  for i in 4: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-competition/google-name-%dx%d.png" % [dimensions.x,dimensions.y])
  expect(panel.get_node("%SaveName").get_global_rect().end.x<=root.get_visible_rect().size.x,"name submit fits width "+str(dimensions))
  expect(panel.get_node("%SignOut").get_global_rect().end.y<=root.get_visible_rect().size.y and panel.get_node("%PlayerName").get_global_rect().position.y>=0,"name setup fits height "+str(dimensions))
  expect(not panel.get_node("%Close").visible and not panel.get_node("%Google").visible,"name setup cannot bypass to play "+str(dimensions))
 panel.queue_free()
 print("GOOGLE AUTH VISUAL RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
