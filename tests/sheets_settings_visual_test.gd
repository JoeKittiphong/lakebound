extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 var panel: Control = load("res://features/social/social_panel.tscn").instantiate()
 root.add_child(panel)
 panel.open()
 panel.get_node("%ConnectionSettings").pressed.emit()
 for dimensions in [Vector2i(1280,720),Vector2i(960,540)]:
  root.size = dimensions
  for i in 5: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/server-settings-%dx%d.png" % [dimensions.x,dimensions.y])
  var bounds := root.get_visible_rect()
  for path in ["%Endpoint","%SaveEndpoint","%CancelEndpoint"]:
   var control: Control = panel.get_node(path)
   if not bounds.encloses(control.get_global_rect()):
    failures += 1
    print("FAIL: settings bounds ", path, " ", dimensions)
 panel.get_node("%CancelEndpoint").pressed.emit()
 if panel.get_node("%EndpointOverlay").visible: failures += 1
 print("SETTINGS VISUAL RESULT: ",failures," failures")
 panel.queue_free()
 quit(1 if failures else 0)
