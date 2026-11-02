extends SceneTree
var scene: Node3D
func _initialize() -> void: call_deferred("run")
func wait_frames(count: int = 10) -> void:
 for i in count:
  await process_frame
func shot(name: String) -> void:
 await wait_frames()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/fishing-hud-motion/" + name + ".png"))
func run() -> void:
 root.size=Vector2i(1280,720)
 root.get_node("FishCollection").recording_enabled=false
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults()
 profile.save_path="res://../output/fishing-hud-motion/preview-profile.cfg"
 scene=load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled=false
 root.add_child(scene)
 current_scene=scene
 await wait_frames(30)
 scene.set_process(false)
 scene.player.set_physics_process(false)
 scene.fishing.set_physics_process(false)
 scene.pond.set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled=false
 scene.hud.get_node("SafeArea/FirstCatch").active=false
 scene.hud.get_node("SafeArea/FirstCatch").hide()
 scene.player.equip_rod(TackleCatalog.item("spinning_rod"))
 scene.player.character_model.equip_reel(TackleCatalog.item("spinning_reel"))
 scene.player.character_model.equip_line(TackleCatalog.item("braid"))
 scene.fishing.cast_position=scene.player.global_position+Vector3(12,-scene.player.global_position.y,0)
 scene.fishing._change_state(FishingController.State.WAITING)
 scene._on_fishing_state_changed()
 await shot("first_person_waiting")
 scene.fishing._change_state(FishingController.State.FIGHT)
 scene.fishing.tension=0.75
 scene.fishing.fish_force=1.0
 scene._on_fishing_state_changed()
 await create_timer(0.8).timeout
 await shot("first_person_fight")
 scene.fishing.rod_input=Vector2.LEFT
 await create_timer(0.8).timeout
 await shot("left_edge")
 scene.fishing.rod_input=Vector2.RIGHT
 await create_timer(0.8).timeout
 await shot("right_edge")
 scene.fishing.rod_input=Vector2.ZERO
 await create_timer(0.15).timeout
 await shot("release_return")
 await create_timer(0.6).timeout
 profile.data.equipped.bait="minnow"
 scene.fishing.bind_profile(profile)
 scene.fishing._change_state(FishingController.State.WAITING)
 scene._on_fishing_state_changed()
 await shot("lure_two_lines")

 scene.fishing._change_state(FishingController.State.READY)
 scene._on_fishing_state_changed()
 await shot("third_person_return")
 scene.queue_free()
 await process_frame
 quit()
