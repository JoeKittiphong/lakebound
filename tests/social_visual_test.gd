extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.save_path = "user://social-visual.cfg"
 profile.data = profile.defaults()
 profile.data.identity.name = "นักตกปลาริมน้ำ"
 profile.data.journal = [{"catch_id":"visual1","name":"ปลานิล","map":"river","species":"tilapia","weight":1.234,"time":100}]
 var panel: Control = load("res://features/social/social_panel.tscn").instantiate()
 root.add_child(panel)
 panel.sheets_url = ""
 panel.open()
 for dimensions in [Vector2i(1280,720), Vector2i(1600,720), Vector2i(960,540)]:
  root.size = dimensions
  for i in 5: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/social-%dx%d.png" % [dimensions.x,dimensions.y])
  var close: Control = panel.get_node("%Close")
  var bottom: Control = panel.get_node("%Personal")
  if close.get_global_rect().end.x > root.get_visible_rect().size.x or bottom.get_global_rect().end.y > root.get_visible_rect().size.y:
   failures += 1
   print("FAIL: layout bounds ", dimensions)
 panel.sheets_url = "https://script.google.com/macros/s/test/exec"
 panel._set_busy(true)
 await process_frame
 var marks: Control = panel.get_node("%ComparisonMarks/First")
 var before := marks.scale.y
 await create_timer(0.4).timeout
 if not panel.get_node("%Comparing").visible or panel.get_node("%Scroll").visible or marks.scale.y == before:
  failures += 1
  print("FAIL: comparison animation")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://exports/social-comparing.png")
 panel._cancel_request()
 panel.sheets_url = ""
 panel._mode_changed(1)
 if not panel.get_node("%Filter").visible or panel.scope != "map":
  failures += 1
  print("FAIL: map tab")
 panel._mode_changed(0)
 panel.online = true
 panel.online_rows = [
  {"player_id":"other","player_name":"นักตกปลาริมน้ำ","species":"tilapia","name":"ปลานิล","map":"river","weight":12.345},
  {"player_id":profile.data.identity.id,"player_name":profile.data.identity.name,"species":"tilapia","name":"ปลานิล","map":"river","weight":9.876}
 ]
 panel._render()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://exports/social-online.png")
 if panel.get_node("%Rows").get_child(0).get_node("Line/Rank").text != "01":
  failures += 1
  print("FAIL: rank numbering")
 for row in panel.get_node("%Rows").get_children():
  for cell in row.get_node("Line").get_children():
   if cell.get_line_count() != 1 or cell.get_global_rect().end.x > row.get_global_rect().end.x:
    failures += 1
    print("FAIL: single-line cell bounds: ", cell.name)
 panel.queue_free()
 print("SOCIAL VISUAL RESULT: ", failures)
 quit(1 if failures else 0)

