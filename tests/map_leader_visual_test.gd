extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 failures += int(not ok)
 print("PASS: " if ok else "FAIL: ",label)
func settle() -> void:
 for i in 6: await process_frame
func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.data.identity.name = "HUD QA"
 profile.save_path = "user://leader-visual-profile.cfg"
 root.get_node("FishCollection").recording_enabled = false
 var scene: Node = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.get_node("FishingEffects").audio_enabled = false
 for i in 20: await physics_frame
 var controller: FishingController = scene.get_node("FishingController")
 controller.set_physics_process(false)
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 hud.get_node("SafeArea/FirstCatch").active = false
 hud.get_node("SafeArea/FirstCatch").hide()
 var badge: Button = hud.get_node("SafeArea/RankingButton")
 var minimap: Control = hud.get_node("SafeArea/Minimap")
 var entry := {"player_name":"นักตกปลาอันดับหนึ่งชื่อยาวมาก", "species":"tilapia", "name":"ปลานิล", "weight":42.68}
 for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(960,540)]:
  root.size = resolution
  await settle()
  badge.present({"loaded":true,"cached":false,"record":entry})
  await settle()
  check(badge.visible and hud.get_global_rect().encloses(badge.get_global_rect()),"leader badge fits viewport "+str(resolution))
  check(not badge.get_global_rect().intersects(minimap.get_global_rect()),"badge does not cover minimap "+str(resolution))
  for path in ["SafeArea/MoveJoystick","SafeArea/MovementActions/LeftActions","SafeArea/MovementActions/Jump","SafeArea/MissionTracker"]:
   var control: Control = hud.get_node(path)
   check(not badge.get_global_rect().intersects(control.get_global_rect()),"badge leaves controls clear: "+path+" "+str(resolution))
  check(badge.get_node("Content/Weight").text=="42.680 กก.","badge shows leader's weight")
  await RenderingServer.frame_post_draw
  var directory := OS.get_environment("LAKEBOUND_QA_DIR")
  if not directory.is_empty():root.get_texture().get_image().save_png(directory+"/map-leader-%dx%d.png"%[resolution.x,resolution.y])
 badge.present({"loaded":true,"cached":true,"record":entry})
 check("แคช" in badge.get_node("Content/Title").text,"offline leader explicitly marked as cached")
 badge.present({"loaded":true,"record":{}})
 check("ยังไม่มี" in badge.get_node("Content/Player").text,"empty map does not invent a winner")
 badge.present({"loaded":false,"failed":true,"record":{}})
 check("ยังโหลด" in badge.get_node("Content/Player").text,"network error is distinct from an empty leaderboard")
 var ranking: Control = hud.get_node("SocialPanel")
 ranking.supabase_url = ""
 var touch := InputEventScreenTouch.new()
 touch.index = 9
 touch.position = badge.get_global_rect().get_center()
 touch.pressed = true
 root.push_input(touch,true)
 touch = touch.duplicate()
 touch.pressed = false
 root.push_input(touch,true)
 await settle()
 check(ranking.visible and paused,"tapping child labels opens map ranking and pauses gameplay")
 check(str(ranking.get_node("%Filter").get_item_metadata(ranking.get_node("%Filter").selected))==str(controller.map_id),"badge opens the current map's ranking")
 ranking.close()
 await settle()
 check(not paused,"closing ranking resumes gameplay")
 scene.queue_free()
 await process_frame
 print("MAP LEADER VISUAL RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
