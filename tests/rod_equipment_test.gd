extends SceneTree
var checks:=0
var failures:=0
var output:=OS.get_environment("LAKEBOUND_QA_DIR")
func _initialize() -> void:
 call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  push_error("FAIL: "+message)
 else: print("PASS: "+message)
func settle() -> void:
 for frame in 4:
  await physics_frame
  await process_frame
func capture(name: String) -> void:
 if output.is_empty() or DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
 root.size=Vector2i(1280,720)
 root.get_node("FishCollection").recording_enabled=false
 var scene:Node3D=load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled=false
 root.add_child(scene)
 current_scene=scene
 await settle()
 scene.set_process(false)
 var player:AnglerPlayer=scene.get_node("Player")
 player.set_physics_process(false)
 var controller:FishingController=scene.get_node("FishingController")
 controller.set_physics_process(false)
 scene.get_node("PondEcosystem").set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled=false
 var hud:FishingHUD=scene.get_node("HUD/FishingHUD")
 hud.get_node("SafeArea/FirstCatch").active=false
 hud.get_node("SafeArea/FirstCatch").hide()
 hud.hide()
 var model:=player.character_model
 var left_attachment:=BoneAttachment3D.new()
 left_attachment.bone_name="hand_l"
 model.skeleton.add_child(left_attachment)
 var camera:=Camera3D.new()
 scene.add_child(camera)
 camera.current=true
 camera.fov=42
 player.set_view_yaw(0)
 var max_error:=0.0
 var original_lengths:Dictionary={}
 for item in TackleCatalog.ITEMS:
  if item.kind!="rod": continue
  player.equip_rod(item)
  model.equip_reel(TackleCatalog.item("fly_reel" if item.id==&"fly_rod" else "spinning_reel" if item.id==&"spinning_rod" else "basic_reel"))
  expect(model.rod_mesh is FishingRodVisual and model.rod_mesh.scene_file_path==item.model_scene.resource_path, "selected Blender rod replaces the held model: "+String(item.id))
  var rod:FishingRodVisual=model.rod_mesh
  expect(rod is DetailedFishingRod and rod.rig != null and rod.tip != null, "new skeleton and a real tip: "+String(item.id))
  expect(not rod.accepts_reel if item.id in [&"pole_rod", &"tenkara_rod"] or (item.rod_spec != null and item.rod_spec.family == "pole") else rod.held_reel!=null, "correct reel seat for rod family: "+String(item.id))
  for state in [FishingController.State.WAITING,FishingController.State.CASTING,FishingController.State.FIGHT]:
   model.set_fishing_state(state,1.0 if state==FishingController.State.WAITING else 0.0,0.5)
   model.update_motion(0.01,false,0,false)
   var action: StringName = &"Fishing_Cast" if state==FishingController.State.CASTING else (&"Fishing_Catch" if state==FishingController.State.FIGHT else &"Fishing_Reel")
   model.animation_player.play(action,0)
   model.animation_player.speed_scale=0
   for phase in [0.0,0.25,0.5,0.75]:
    model.animation_player.seek(model.animation_player.get_animation(action).length*phase,true)
    model.animation_player.advance(0)
    await settle()
    var right_index:=model.skeleton.find_bone("hand_r")
    var right_position:=model.skeleton.global_transform*model.skeleton.get_bone_global_pose(right_index).origin
    var grip:Node3D=rod.find_child("PrimaryGrip",true,false)
    expect(right_position.distance_to(grip.global_position)<0.085, "right palm stays on handle: %s %s %.2f" % [item.id,action,phase])
    var hand_error:=left_attachment.global_position.distance_to(model.left_hand_target.global_position)
    max_error=maxf(max_error,hand_error)
    expect(hand_error<0.015, "left hand follows support/crank: %s %s %.2f error %.3fm" % [item.id,action,phase,hand_error])
    expect(rod.tip.global_position.is_finite(), "line tip remains finite: "+String(item.id))
   if state==FishingController.State.WAITING:
    original_lengths[item.id]=rod.tip.global_position.distance_to(grip_position(rod))
    var target:=model.rod_grip.global_position+Vector3(0,-.1,0)
    camera.global_position=target+Vector3(1.4,.35,1.6)
    camera.look_at(target)
    await settle()
    await capture("rod_hold_"+String(item.id))
    camera.global_position=target+Vector3(-1.4,.35,-1.6)
    camera.look_at(target)
    await settle()
    await capture("rod_front_"+String(item.id))
   elif item.id in [&"spinning_rod",&"surf_rod",&"pole_rod"]:
    var target:=model.rod_grip.global_position
    camera.global_position=target+Vector3(1.3,.35,1.5)
    camera.look_at(target)
    await settle()
    await capture("rod_%s_state%d" % [item.id,state])
    camera.global_position=target+Vector3(-1.3,.35,-1.5)
    camera.look_at(target)
    await settle()
    await capture("rod_front_%s_state%d" % [item.id,state])
  rod.set_load(0.8,0.5)
  expect(rod.load_amount > 0.01, "selected rod bends under actual load: "+String(item.id))
 expect(original_lengths.surf_rod>original_lengths.jigging_rod*1.5, "long surf and short jigging models have genuinely different lengths")
 player.equip_rod(TackleCatalog.item("trolling_rod"))
 model.equip_reel(TackleCatalog.item("electric_reel"))
 expect(model.rod_mesh.held_reel.scene_file_path.ends_with("reel_06_conventional_lever.tscn"), "character's mounted reel also changes with equipped reel")
 model.set_fishing_state(FishingController.State.READY,0,0)
 model.update_motion(0.1,false,0,false)
 await settle()
 expect(not model.left_hand_ik.is_running() and model.rod_mesh.visible and model.carrying, "fishing ends in one-handed carry with the left hand released")
 print("MAX LEFT HAND CONTACT ERROR: %.4fm" % max_error)
 scene.queue_free()
 await process_frame
 print("ROD EQUIPMENT RESULT: %d checks, %d failures" % [checks,failures])
 quit(0 if failures==0 else 1)
func grip_position(rod:Node3D)->Vector3:
 return (rod.find_child("PrimaryGrip",true,false) as Node3D).global_position
