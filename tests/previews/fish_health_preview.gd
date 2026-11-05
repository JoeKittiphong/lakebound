extends SceneTree
var scene: Node3D
func _initialize() -> void: call_deferred("run")
func frames(count: int = 8) -> void:
 for i in count: await process_frame
func shot(name: String) -> void:
 await frames(12)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/fish-health/"+name+".png"))
func run() -> void:
 root.size=Vector2i(1280,720)
 root.get_node("FishCollection").recording_enabled=false
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults()
 profile.save_path="res://../output/fish-health/preview-profile.cfg"
 profile.data.equipped.rod="spinning_rod"
 profile.data.equipped.reel="spinning_reel"
 profile.data.equipped.line="heavy_braid"
 scene=load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled=false
 root.add_child(scene)
 current_scene=scene
 await frames(20)
 scene.set_process(false)
 scene.player.set_physics_process(false)
 scene.fishing.set_physics_process(false)
 scene.pond.set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled=false
 scene.hud.get_node("SafeArea/FirstCatch").active=false
 scene.hud.get_node("SafeArea/FirstCatch").hide()
 scene.fishing.bind_profile(profile)
 var camera: Camera3D=scene.camera_rig.get_node("FishingCamera3D")
 for sample in [[0.2,"small_fish"],[5.0,"medium_fish"],[60.0,"large_fish"]]:
  var fish:=FishState.new()
  fish.species=load("res://data/fish/tilapia.tres" if float(sample[0])<10 else "res://data/fish/giant_catfish.tres")
  fish.weight=sample[0]
  fish.id=80
  fish.position=scene.player.global_position-camera.global_basis.z*12
  fish.position.y=1.0
  scene.fishing.active_fish=fish
  scene.fishing.fight.begin(fish,scene.fishing.tuning)
  scene.fishing.line_length=12.0
  scene.fishing._change_state(FishingController.State.FIGHT)
  scene.fishing.tension=(scene.fishing.yellow_start+scene.fishing.red_start)*0.5
  scene.fishing.fight.line_load_kgf=fish.weight*0.5
  await create_timer(0.5).timeout
  await shot(sample[1])
 scene.fishing.fight.health=scene.fishing.fight.maximum_health*0.4
 scene.fishing.active_fish.stamina=0.4
 await shot("health_decreasing")
 scene.fishing.fight.health=0.0
 scene.fishing.fight.advance(0.1,scene.player.global_position,scene.fishing.active_fish,Vector2.ZERO,scene.fishing.tuning)
 await shot("exhausted_all_yellow")
 for side in [-1.0,1.0]:
  scene.fishing.rod_input=Vector2(side,0)
  await create_timer(0.6).timeout
  await shot("third_person_left" if side<0 else "third_person_right")
 scene.fishing.rod_input=Vector2.ZERO
 await create_timer(0.6).timeout
 await shot("third_person_center")
 scene.fishing.reset_cast()
 await shot("reset_restores_hud")
 scene.queue_free()
 await process_frame
 quit()
