extends SceneTree

var failures := 0
var checks := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: ", message)

func render_frames() -> void:
 for frame in 5:
  await process_frame
 await RenderingServer.frame_post_draw

func run() -> void:
 if output.is_empty():
  output = "res://exports/qa-expansion-visual"
 DirAccess.make_dir_recursive_absolute(output)
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.save_path = "user://visual-test-%d.cfg" % Time.get_ticks_usec()
 profile.data = profile.defaults()
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.get_node("HUD/FishingHUD/SafeArea/FirstCatch").save_path = "user://visual-tutorial.cfg"
 root.add_child(scene)
 current_scene = scene
 var controller: FishingController = scene.get_node("FishingController")
 controller.set_physics_process(false)
 scene.set_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 var panel: Control = hud.get_node("TacklePanel")
 # Opening the first modal pauses physics immediately. Establish actual floor
 # contact before it opens so the later cast does not depend on render speed.
 for frame in 30:
  await physics_frame
 for size in [Vector2i(1280, 720), Vector2i(1600, 720)]:
  root.size = size
  hud._on_tackle_pressed()
  await render_frames()
  var content: Control = panel.get_node("Card/Content")
  expect(content.get_global_rect().end.y <= root.size.y and content.get_global_rect().position.y >= 0, "equipment fits viewport %d" % size.x)
  var rows := panel.get_node("Card/Content/Tabs/Tackle/Scroll/Rows")
  expect(rows.get_child_count() == TackleCatalog.ITEMS.size(), "all authored item rows instantiated")
  var row := rows.get_child(2)
  row.get_node("Buy").pressed.emit()
  # minnow is reusable but multiple copies are valid.
  expect(profile.quantity("minnow") >= 2, "shop button buys actual inventory")
  profile.equip("minnow")
  profile.break_line(15.0, "minnow")
  await render_frames()
  expect(panel.get_node("Card/Content/Recovery").visible and panel.get_node("Card/Content/Recovery/Choices/Ad").disabled, "loss UI shows real unavailable ad status")
  root.get_texture().get_image().save_png(output.path_join("recovery-%d.png" % size.x))
  panel.get_node("Card/Content/Recovery/Choices/Discard").pressed.emit()
  expect(profile.data.pending.is_empty(), "discard button resolves persisted pending loss")
  panel.get_node("Card/Content/Tabs").current_tab = 3
  await render_frames()
  expect("???" in panel.get_node("Card/Content/Tabs/Map/Info").text, "undiscovered boss name hidden in map information")
  root.get_texture().get_image().save_png(output.path_join("map-%d.png" % size.x))
  panel.get_node("Card/Content/Tabs").current_tab = 0
  await render_frames()
  root.get_texture().get_image().save_png(output.path_join("shop-%d.png" % size.x))
  panel.close()
  expect(not paused, "rendered modal closes and releases pause")
  profile.data = profile.defaults()
 profile.equip("minnow")
 controller.refresh_equipment()
 expect(controller.cast(), "lure casts for visual depth verification")
 controller.advance(controller.tuning.cast_duration, controller.player.global_position)
 await render_frames()
 var effects: Node3D = scene.get_node("FishingEffects")
 expect(effects.get_node("LureVisual").visible and not effects.get_node("Bobber").visible, "lure renders its authored model instead of a surface bobber")
 expect(is_equal_approx(effects.get_node("LureVisual").global_position.y, effects.water_height - controller.cast_position.y), "visible lure and line target use simulated underwater depth")
 root.get_texture().get_image().save_png(output.path_join("lure-action-1600.png"))
 controller.cancel()
 scene.free()
 print("EXPANSION VISUAL RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
