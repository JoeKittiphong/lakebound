extends SceneTree
## Exercise the saved performance and actual line/splash cues on one manual clock.
var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1

func foot_positions(scene: Node3D) -> Array[Vector3]:
 var s: Skeleton3D = scene.angler.skeleton
 s.force_update_all_bone_transforms()
 var result: Array[Vector3] = []
 for name in ["foot_l", "foot_r"]:
  result.append(s.global_transform * s.get_bone_global_pose(s.find_bone(name)).origin)
 return result

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var packed := load("res://features/loading/cinematic/loading_cinematic.tscn") as PackedScene
 for settings in [[1.0, 60.0], [0.5, 30.0], [2.0, 30.0]]:
  var scene: Node3D = packed.instantiate()
  scene.playback_speed = settings[0]
  root.add_child(scene)
  scene.set_process(false)
  scene.timeline.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  scene.timeline.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
  for name in ["WaterAmbience", "Footstep", "CastSound", "SplashSound"]:
   scene.get_node(name).volume_db = -80
  expect(not scene.angler.animation_player.active and not scene.angler.locomotion_tree.active, "one skeleton animation owner at speed %.1f" % settings[0])
  scene.angler.skeleton.force_update_all_bone_transforms()
  var first_hand: Vector3 = scene.angler.skeleton.global_transform * scene.angler.skeleton.get_bone_global_pose(scene.angler.skeleton.find_bone("hand_r")).origin
  expect(absf(first_hand.x - scene.actor_motion.position.x) < 0.3, "very first loading frame already has the authored carry pose, not a T-pose")
  var frozen_feet: Array[Vector3] = []
  var max_slip := 0.0
  var released := false
  var landed := false
  var early_release := false
  var flight_reversed := false
  var previous_z := 100.0
  var max_root_jump := 0.0
  var previous_position: Vector3 = scene.actor_motion.position
  var dt: float = 1.0 / settings[1]
  for frame in int(9.4 / settings[0] / dt):
   scene.timeline.advance(dt)
   scene.angler.skeleton.force_update_all_bone_transforms()
   scene._process(dt)
   var time: float = scene.timeline.current_animation_position
   max_root_jump = maxf(max_root_jump, previous_position.distance_to(scene.actor_motion.position))
   previous_position = scene.actor_motion.position
   if time < scene._release_time - 0.001 and not scene.finished and scene.bobber.visible:
    early_release = true
   if not released and scene._released:
    released = true
    expect(scene.stage == scene.Stage.CASTING and time >= 6.76 and time <= 6.85, "line releases on the forward stroke at speed %.1f" % settings[0])
    expect(scene._release_origin.z < scene.actor_motion.global_position.z - 0.2, "release starts in front of the angler")
   if released and not scene._landed:
    if scene.bobber.global_position.z > previous_z + 0.001:
     flight_reversed = true
    previous_z = scene.bobber.global_position.z
   if scene._landed and not landed:
    landed = true
    expect(scene.bobber.global_position.distance_to(scene.landing.global_position) < 0.001, "bobber reaches water contact before splash")
   if scene.stage == scene.Stage.CASTING and time > 5.7:
    var feet := foot_positions(scene)
    if frozen_feet.is_empty():
     frozen_feet = feet
    else:
     for index in feet.size():
      max_slip = maxf(max_slip, feet[index].distance_to(frozen_feet[index]))
   if frame % 120 == 0:
    await process_frame
  expect(not early_release and released and landed, "wind-up, release and splash occur in order")
  expect(not flight_reversed, "bobber travels continuously toward the lake")
  expect(max_slip < 0.006, "cast keeps ankles planted (max drift %.5f m)" % max_slip)
  expect(frozen_feet.size() == 2 and frozen_feet[0].x < frozen_feet[1].x - 0.2, "casting stance keeps each foot on its own side without crossing legs")
  expect(max_root_jump < 0.09, "walk path has no frame-sized teleport")
  expect(scene.finished and scene.stage == scene.Stage.WAITING, "all playback speeds finish in waiting")
  expect(scene.actor_motion.position.is_equal_approx(Vector3(-2, 0.9, 0.1)), "waiting holds the final dock position")
  expect(scene.angler.animation_player.get_animation("Walk").get_track_count() == 19, "imported gameplay walk remains unchanged")
  scene.free()
 var returned: Node3D = packed.instantiate()
 returned.play_intro = false
 root.add_child(returned)
 returned.set_process(false)
 expect(returned.finished and returned.stage == returned.Stage.WAITING, "returning from gameplay starts directly in waiting")
 expect(returned.bobber.visible and returned.angler.rod_mesh.visible and returned.fishing_line.visible, "return menu has the same rod and floating line")
 var wait: Animation = returned.timeline.get_animation("waiting")
 var max_loop_angle := 0.0
 for track in wait.get_track_count():
  if wait.track_get_type(track) == Animation.TYPE_ROTATION_3D:
   max_loop_angle = maxf(max_loop_angle, wait.rotation_track_interpolate(track, 0).angle_to(wait.rotation_track_interpolate(track, wait.length)))
 expect(max_loop_angle < 0.001, "waiting loop has matching bone rotations at its seam")
 returned.free()
 var stalled: Node3D = packed.instantiate()
 root.add_child(stalled)
 stalled.set_process(false)
 stalled.timeline.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 stalled.timeline.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
 stalled.timeline.advance(6.6)
 stalled._process(6.6)
 stalled.timeline.advance(1.2)
 stalled._process(1.2)
 expect(stalled._landed and stalled.bobber.global_position.is_equal_approx(stalled.landing.global_position), "a stalled frame crossing release and splash cannot restart the flight")
 stalled.free()
 await process_frame
 await create_timer(0.15).timeout
 print("LOADING MOTION RESULT: %d checks, %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
