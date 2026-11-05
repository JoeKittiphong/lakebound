extends "res://tests/competition_test.gd"
func run() -> void:
 var service: Node=root.get_node("Competition")
 service.enabled=false
 root.get_node("RankingOnline").enabled=false
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults()
 profile.data.identity.name="นักตกปลา QA"
 profile.save_path="user://match-hud-test.cfg"
 service._identity=profile.data.identity.id
 service.room=fixture()
 service.room.phase="running"
 service.room.starts_at=999
 service.room.ends_at=1600
 service._clock_server=1000.0
 service._clock_ticks=Time.get_ticks_msec()
 var game: Node3D=load("res://features/regions/lotus_marsh.tscn").instantiate()
 root.add_child(game)
 current_scene=game
 await process_frame
 var hud: FishingHUD=game.hud
 var match_hud: CanvasLayer=game.get_node("MatchHUD")
 var button: Button=hud.get_node("SafeArea/PerspectiveButton")
 expect(hud.competition_mode,"competitive HUD mode is configured")
 for i in 3:
  var member: Dictionary=service.room.members[1].duplicate(true)
  member.id=str(i+2).repeat(32)
  member.name="นักตกปลาชื่อยาวมากทดสอบหน้าจอ "+str(i+3)
  member.rank=i+2
  member.grams=2345+i*100
  service.room.members.append(member)
 match_hud.render()
 expect(not match_hud.has_node("Overlay/Board/Content/Header/Room"),"room/results shortcut removed from scoreboard")
 expect(match_hud.get_node("%Rule").text==MatchRules.description(service.room),"rule appears beside the clock")
 expect(match_hud.get_node("%Scores").get_child_count()==5,"scoreboard supports five competitors")
 for width in [1280,1024,1600]:
  root.size=Vector2i(width,720)
  for i in 4:await process_frame
  expect(not hud.get_node("SafeArea/RankingButton").visible,"map ranking hidden during match at "+str(width))
  expect(not hud.get_node("SafeArea/MissionTracker").visible and not hud.get_node("SafeArea/TopBar/Actions/MissionButton").visible,"mission surfaces hidden during match at "+str(width))
  var board: Control=match_hud.get_node("Overlay/Board")
  expect(not board.get_global_rect().intersects(hud.get_node("SafeArea/Minimap").get_global_rect()),"scoreboard clears minimap at "+str(width))
  expect(not board.get_global_rect().intersects(hud.get_node("SafeArea/MovementActions/LeftActions/Run").get_global_rect()),"scoreboard clears movement buttons at "+str(width))
  expect(button.get_global_rect().end.x<hud.get_node("SafeArea/BagDock/Equipment/Rod").get_global_rect().position.x,"perspective button sits before rod slot at "+str(width))
  var bag_rect: Rect2=hud.get_node("SafeArea/BagDock/Equipment/Rod").get_global_rect()
  var safe_rect: Rect2=hud.get_node("SafeArea").get_global_rect()
  expect(bag_rect.position.y>safe_rect.position.y+safe_rect.size.y*0.7 and bag_rect.end.y<=safe_rect.end.y,"bag remains at bottom inside safe area at "+str(width))
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("user://match-hud-%d.png"%width)
 for state in [FishingController.State.READY,FishingController.State.CASTING,FishingController.State.WAITING,FishingController.State.BITE,FishingController.State.FIGHT,FishingController.State.RESULT,FishingController.State.LOST]:
  game.fishing.state=state
  hud._apply_fishing_visibility(state)
  button.button_pressed=true
  game._on_fishing_state_changed()
  var deployed: bool = state in [FishingController.State.WAITING,FishingController.State.BITE,FishingController.State.FIGHT]
  expect(button.visible and game.camera_rig.first_person == deployed,"first-person preference applies only after cast in state "+str(state))
  button.button_pressed=false
  expect(not game.camera_rig.first_person,"third-person selectable in state "+str(state))
 service.room.clear()
 game.get_node("MatchSession").set_process(false)
 match_hud.set_process(false)
 game.queue_free()
 await process_frame
 print("MATCH HUD RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
