extends SceneTree
var checks := 0
var failures := 0
var game: Node3D
var profile: AnglerProfile

func _initialize() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ",message)
 if not ok: failures += 1
func ticks(count := 5) -> void:
 for i in count: await physics_frame
func tap(button: Control) -> void:
 for down in [true,false]:
  var event := InputEventScreenTouch.new()
  event.index=6;event.position=button.get_global_rect().get_center();event.pressed=down
  root.push_input(event,true)
 await ticks(3)
func capture(label: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join(label+".png"))
func open_game() -> void:
 game=load("res://features/gameplay/gameplay.tscn").instantiate();game.economy_enabled=true
 root.add_child(game);current_scene=game
 game.get_node("FishingEffects").audio_enabled=false
 game.fishing.set_physics_process(false);game.pond.set_physics_process(false)
 await ticks(25)
 game.hud.get_node("SafeArea/FirstCatch")._skip()
func aim_valid() -> bool:
 var reasons: Array = []
 for yaw in [-PI*.5,-PI*.5+.3,-PI*.5-.3,0.0,PI]:
  for pitch in [-.17,0.0,.08,.17,.25]:
   game.camera_rig.rotation=Vector3(pitch,yaw,0)
   await ticks(2)
   game.boats.update()
   if game.boats.placement_error.is_empty(): return true
   if not reasons.has(game.boats.placement_error): reasons.append(game.boats.placement_error)
 print("PLACEMENT DEBUG: ",reasons," player=",game.player.position," aim=",game.boats.candidate)
 return false
func run() -> void:
 root.get_node("FishCollection").recording_enabled=false
 profile=root.get_node("AnglerSave");profile.data=profile.defaults();profile.save_path="user://owned-boats.cfg"
 expect(profile.equipped("boat")==null and profile.quantity("lake_skiff")==0,"new player has no free boat or selected boat")
 expect(not profile.buy("lake_skiff") and profile.data.coins==350,"insufficient funds cannot buy boat")
 profile.grant_trial_equipment()
 expect(profile.quantity("lake_skiff")==0,"trial equipment does not grant a free boat")
 profile.data=profile.defaults();profile.data.coins=2000
 profile.data.cloud.tracking=true
 expect(profile.buy("lake_skiff") and profile.data.coins==500 and profile.quantity("lake_skiff")==1,"buy spends coins exactly once and grants permanent boat")
 expect(not profile.buy("lake_skiff") and profile.data.coins==500,"permanent ownership rejects duplicate purchase")
 expect(profile.equip("lake_skiff") and profile.equipped("boat").boat_spec!=null,"purchased boat can be selected as equipment")
 expect(CloudCatalog.code("item","lake_skiff")==81 and profile.data.cloud.events[-1][2]==[20,81],"boat selection uses stable cloud item ID")
 profile.load_profile()
 expect(profile.quantity("lake_skiff")==1 and profile.equipped("boat")!=null,"ownership and selected boat survive disk reload")
 await open_game()
 var dry: Vector3 = game.player.position
 expect(not game.vessel.deployed and not game.vessel.visible and game.vessel.collision_layer==0,"map starts without a physical or visible boat even when owned")
 var slot: Button=game.hud.get_node("SafeArea/BagDock/Equipment/Boat")
 expect(game.hud.get_node("SafeArea/BagDock/Equipment").get_child_count()==5 and slot.get_node("Preview").resource==profile.equipped("boat"),"fifth equipment slot previews selected boat")
 expect(profile.unequip("boat"),"owned boat can be unselected before deployment")
 await tap(slot)
 expect(game.hud.get_node("TacklePanel").visible and game.hud.get_node("TacklePanel/Shop").category==6,"unselected owned boat opens the boat equipment category")
 await tap(game.hud.get_node("TacklePanel/Shop").inspector.get_node("%Equip"))
 game.hud.get_node("TacklePanel").close();await ticks(3)
 expect(profile.equipped("boat")!=null,"inventory selection reconnects owned boat to the boat slot")
 await tap(slot)
 expect(game.boats.placing and game.hud.get_node("BoatPlacement").visible and not game.player.input_enabled,"boat slot opens placement preview and suspends walking")
 expect(not game.vessel.deployed and game.vessel.collision_layer==0,"placement ghost is not a boardable or colliding boat")
 var camera_yaw: float=game.camera_rig.rotation.y
 var look:=Vector2(root.get_visible_rect().size.x*.7,160)
 var touch:=InputEventScreenTouch.new();touch.index=2;touch.pressed=true;touch.position=look;root.push_input(touch,true)
 var drag:=InputEventScreenDrag.new();drag.index=2;drag.position=look+Vector2(60,0);drag.relative=Vector2(60,0);root.push_input(drag,true)
 touch.pressed=false;root.push_input(touch,true)
 await ticks()
 expect(not is_equal_approx(game.camera_rig.rotation.y,camera_yaw),"placement allows real touch camera panning")
 await tap(game.hud.get_node("BoatPlacement/Panel/Content/Buttons/Cancel"))
 expect(not game.boats.placing and game.player.input_enabled and not game.vessel.deployed,"cancel restores controls and consumes no boat")
 await tap(slot)
 game.hud.open_tackle()
 expect(not game.boats.placing and not game.hud.get_node("BoatPlacement").visible,"opening a modal cancels placement before gameplay pauses")
 game.hud.get_node("TacklePanel").close();await ticks(3)
 await tap(slot)
 profile.unequip("boat")
 game.boats.confirm()
 expect(not game.boats.placing and not game.vessel.deployed,"confirmation rechecks boat ownership and selection")
 profile.equip("lake_skiff")
 await tap(slot)
 expect(await aim_valid(),"player can aim a valid reachable water placement from the shore")
 expect(not game.boats.placement_reason(Vector3.INF,0).is_empty(),"invalid aim is rejected")
 expect(not game.boats.placement_reason(game.player.position,0).is_empty(),"placing at the player's feet is rejected")
 await capture("boat-placement")
 await tap(game.hud.get_node("BoatPlacement/Panel/Content/Buttons/Confirm"))
 expect(game.vessel.deployed and game.vessel.visible and game.vessel.collision_layer==1 and profile.boat_in_use,"confirm deploys a real owned hull")
 expect(profile.quantity("lake_skiff")==1 and profile.data.coins==500,"deployment does not consume ownership or charge again")
 var boat: FishingBoat=game.vessel
 game.player.position=boat.position+boat.basis.x*3.5
 game.player.position.y=game.player.pond.definition.surface_height()-game.player.swim_float_depth
 await ticks(12)
 expect(boat.can_board(game.player),"player can approach and board deployed boat")
 game._on_boat_action();await ticks()
 expect(game.player.boat==boat and boat.mode==FishingBoat.Mode.DRIVING,"action boards and starts driving")
 await tap(game.hud.get_node("SafeArea/BoatActions/Pack"))
 game.boats.pack()
 expect(boat.deployed and game.player.boat==boat,"driving blocks both touch and direct packing requests")
 expect(not profile.unequip("boat"),"deployed boat cannot be removed from the loadout")
 game._on_boat_action();await ticks()
 expect(boat.mode==FishingBoat.Mode.FISHING and not game.player.character_model.driving,"leave helm enables standing and fishing")
 var before: Vector3=game.player.position
 game.camera_rig.rotation.y=boat.rotation.y
 var stick: TouchJoystick=game.hud.move_joystick
 var center:=stick.get_global_rect().get_center()
 touch=InputEventScreenTouch.new();touch.index=0;touch.position=center+Vector2(0,-55);touch.pressed=true;root.push_input(touch,true)
 await ticks(25)
 touch.pressed=false;root.push_input(touch,true)
 expect(game.player.position.distance_to(before)>.25 and game.player.boat==boat,"actual joystick walks to another fishing position on deck")
 for i in 120: boat.walk_passenger(-boat.global_basis.z,1.0/60)
 expect(boat.deck_bounds.has_point(Vector2(boat.deck_position.x,boat.deck_position.z)+Vector2(.0001,.0001)),"deck boundary prevents walking off the hull")
 for resolution in [Vector2i(960,540),Vector2i(1280,720),Vector2i(2400,1080)]:
  root.size=resolution;await ticks()
  var actions: Control=game.hud.get_node("SafeArea/BoatActions")
  var rod: Control=game.hud.rod_joystick
  expect(game.hud.get_global_rect().encloses(actions.get_global_rect()),"boat buttons fit viewport "+str(resolution))
  expect(actions.get_global_rect().end.y<rod.get_global_rect().position.y and absf(actions.get_global_rect().get_center().x-rod.get_global_rect().get_center().x)<1,"boat buttons share cast-distance column above rod joystick")
  expect(actions.get_node("Pack").get_global_rect().position.y>actions.get_node("Exit").get_global_rect().position.y,"pack button is below exit")
  expect(not actions.get_global_rect().has_point(Vector2(root.get_visible_rect().size.x*.7,160)),"camera pan area remains clear")
  await capture("boat-actions-%dx%d"%[resolution.x,resolution.y])
 game.boats.pack();await ticks(10)
 expect(not boat.deployed and game.player.boat==null and not profile.boat_in_use,"standing passenger exits safely before packing")
 expect(profile.quantity("lake_skiff")==1,"packing preserves purchased equipment")
 if game.player.swimming:
  game.boats.use();expect(not game.boats.placing,"swimming cannot summon a boat")
 game.player.position=dry;game.player.velocity=Vector3.ZERO;await ticks(20)
 game.boats.use();expect(await aim_valid(),"stored boat can be deployed again from shore")
 game.boats.confirm();boat=game.vessel
 game.player.position=boat.position+Vector3.UP*.3;game._on_boat_action();await ticks(24)
 expect(game.player.boat==boat,"fixture exits map while aboard")
 game.queue_free();await ticks(3);current_scene=null
 profile.load_profile();await open_game()
 expect(not game.vessel.deployed and not game.vessel.visible and game.player.boat==null,"returning to map never restores a deployed hull")
 expect(game.player.swimming,"returning after aboard exit resumes floating in water")
 expect(profile.quantity("lake_skiff")==1 and profile.equipped("boat")!=null,"session cleanup preserves boat purchase and selection")
 game.boats.use();expect(not game.boats.placing,"returned swimmer must reach shore before summoning")
 await capture("returned-without-boat")
 game.queue_free();await ticks(3)
 print("OWNED BOATS RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
