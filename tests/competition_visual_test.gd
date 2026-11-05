extends "res://tests/competition_test.gd"
func run() -> void:
 var service: Node=root.get_node("Competition")
 service.enabled=false
 root.get_node("RankingOnline").enabled=false
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults()
 profile.data.identity.name="นักตกปลา QA"
 service._identity=profile.data.identity.id
 var panel: Control=load("res://features/competition/match_panel.tscn").instantiate()
 panel.auto_travel=false
 root.add_child(panel)
 panel.open()
 for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(960,540)]:
  root.size=dimensions
  service.room={}
  panel.render()
  for i in 3: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-competition/entry-%dx%d.png" % [dimensions.x,dimensions.y])
  expect(panel.get_node("%Join").get_global_rect().end.x<=root.get_visible_rect().size.x,"join fits "+str(dimensions))
  panel.get_node("%Rule").select(0)
  panel.get_node("%Rule").item_selected.emit(0)
  for i in 3: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-competition/species-entry-%dx%d.png" % [dimensions.x,dimensions.y])
  expect(panel.get_node("%Create").get_global_rect().end.x<=root.get_visible_rect().size.x and panel.get_node("%QuickJoin").get_global_rect().position.x>=0,"quick join and create fit target mode "+str(dimensions))
  service.room=fixture()
  for i in 3:
   var member: Dictionary=service.room.members[1].duplicate(true)
   member.id=str(i+2).repeat(32)
   member.name="นักตกปลาทะเลสาบป่าดิบ "+str(i+3)
   service.room.members.append(member)
  panel.render()
  for i in 3: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-competition/lobby-%dx%d.png" % [dimensions.x,dimensions.y])
  expect(panel.get_node("%Leave").get_global_rect().end.y<=root.get_visible_rect().size.y,"lobby actions fit "+str(dimensions))
  expect(panel.get_node("%Rows").get_child_count()==5,"five member rows render")
  service.room.phase="finished"
  service.room.members[0].grams=12000
  service.room.members[0].best=[6000,4000,2000]
  panel.render()
  for i in 3: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-competition/results-%dx%d.png" % [dimensions.x,dimensions.y])
 service.room.clear()
 panel.queue_free()
 print("COMPETITION VISUAL RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
