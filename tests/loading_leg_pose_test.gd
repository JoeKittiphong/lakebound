extends SceneTree
## Inspect the rendered skeleton and CPU-skinned shoe vertices across the whole intro.
var failures := 0
var checks := 0
const SAMPLE_FPS := 120.0
var shoes: Array = []
var bind_bones: Array[int] = []
var bind_poses: Array[Transform3D] = []

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1

func cache_shoes(s: Skeleton3D) -> void:
 var body := s.get_child(0) as MeshInstance3D
 for bind in body.skin.get_bind_count():
  bind_bones.append(s.find_bone(body.skin.get_bind_name(bind)))
  bind_poses.append(body.skin.get_bind_pose(bind))
 var arrays := body.mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
 var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
 var influences := weights.size() / vertices.size()
 for vertex in vertices.size():
  var membership := {"l": 0.0, "r": 0.0}
  var bindings := []
  for j in influences:
   var index := int(vertex * influences + j)
   if weights[index] < 0.001:
    continue
   var bind := bones[index]
   bindings.append([bind, weights[index]])
   var name := s.get_bone_name(bind_bones[bind])
   if name.begins_with("foot_") or name.begins_with("ball_"):
    membership[String(name).right(1)] += weights[index]
  for side in ["l", "r"]:
   if membership[side] > 0.5:
    shoes.append({"side": side, "vertex": vertices[vertex], "bindings": bindings})

func shoe_heights(s: Skeleton3D, floor_y: float) -> Dictionary:
 var transforms: Array[Transform3D] = []
 for bind in bind_bones.size():
  transforms.append(s.global_transform * s.get_bone_global_pose(bind_bones[bind]) * bind_poses[bind])
 var heights := {"l": 100.0, "r": 100.0}
 for shoe in shoes:
  var position := Vector3.ZERO
  for binding in shoe.bindings:
   position += (transforms[binding[0]] * shoe.vertex) * binding[1]
  heights[shoe.side] = minf(heights[shoe.side], position.y - floor_y)
 return heights

func point(s: Skeleton3D, bone: String) -> Vector3:
 return s.global_transform * s.get_bone_global_pose(s.find_bone(bone)).origin

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var scene: Node3D = load("res://features/loading/cinematic/loading_cinematic.tscn").instantiate()
 root.add_child(scene)
 scene.set_process(false)
 scene.timeline.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 for name in ["WaterAmbience", "Footstep", "CastSound", "SplashSound"]:
  scene.get_node(name).volume_db = -80
  scene.get_node(name).stop()
 var s: Skeleton3D = scene.angler.skeleton
 cache_shoes(s)
 expect(shoes.size() > 200, "inspect actual skinned shoe geometry on both feet")
 var metrics := {"lowest_sole": 100.0, "highest_support_sole": -100.0, "max_standing_stagger": 0.0, "max_standing_knee_bend": 0.0, "min_knee_forward": 1.0, "max_leg_rotation_per_second": 0.0, "closing_support_drift": 0.0, "closing_step_lift": 0.0, "walk_contact_speed": 0.0, "min_ankle_separation": 100.0}
 var prior_rotations := {}
 var prior_toes := {}
 var support_anchor := Vector3.ZERO
 var frames := 0
 for clip_name in ["arrival", "waiting"]:
  var clip: Animation = scene.timeline.get_animation(clip_name)
  scene.timeline.play(clip_name)
  prior_rotations.clear()
  prior_toes.clear()
  for frame in int(round(clip.length * SAMPLE_FPS)) + 1:
   var time := float(frame) / SAMPLE_FPS
   scene.timeline.seek(time, true)
   s.force_update_all_bone_transforms()
   var left := point(s, "foot_l")
   var right := point(s, "foot_r")
   var heights := shoe_heights(s, scene.actor_motion.position.y)
   var stationary: bool = clip_name == "waiting" or time < 0.8 or time >= 5.55
   if minf(heights.l, heights.r) < metrics.lowest_sole:
    metrics.lowest_sole_at = "%s %.3f" % [clip_name, time]
   metrics.lowest_sole = minf(metrics.lowest_sole, minf(heights.l, heights.r))
   metrics.highest_support_sole = maxf(metrics.highest_support_sole, minf(heights.l, heights.r))
   metrics.min_ankle_separation = minf(metrics.min_ankle_separation, right.x - left.x)
   if stationary:
    metrics.max_standing_stagger = maxf(metrics.max_standing_stagger, absf(left.z - right.z))
   if clip_name == "arrival" and time >= 5.0 and time <= 5.55:
    if support_anchor == Vector3.ZERO:
     support_anchor = right
    metrics.closing_support_drift = maxf(metrics.closing_support_drift, Vector2(right.x - support_anchor.x, right.z - support_anchor.z).length())
    metrics.closing_step_lift = maxf(metrics.closing_step_lift, heights.l)
   for side in ["l", "r"]:
    var hip := point(s, "thigh_" + side)
    var knee := point(s, "calf_" + side)
    var ankle := point(s, "foot_" + side)
    var axis := (ankle - hip).normalized()
    var pole := (knee - hip).slide(axis)
    var bend := 180.0 - rad_to_deg((hip - knee).angle_to(ankle - knee))
    if stationary:
     metrics.max_standing_knee_bend = maxf(metrics.max_standing_knee_bend, bend)
    if pole.length() > 0.015:
     metrics.min_knee_forward = minf(metrics.min_knee_forward, pole.normalized().dot(Vector3.FORWARD))
    var toe := point(s, "ball_" + side)
    if clip_name == "arrival" and time > 1.4 and time < 4.8 and prior_toes.has(side):
     var old: Vector3 = prior_toes[side]
     if toe.y < 0.908 and old.y < 0.908:
      var speed := Vector2(toe.x - old.x, toe.z - old.z).length() * SAMPLE_FPS
      if speed > metrics.walk_contact_speed:
       metrics.walk_contact_at = "%s %.3f old=%s new=%s" % [side, time, old, toe]
      metrics.walk_contact_speed = maxf(metrics.walk_contact_speed, speed)
    prior_toes[side] = toe
    for bone in ["thigh_" + side, "calf_" + side, "foot_" + side]:
     var rotation := s.get_bone_pose_rotation(s.find_bone(bone))
     if prior_rotations.has(bone):
      var speed := rotation.angle_to(prior_rotations[bone]) * SAMPLE_FPS
      if speed > metrics.max_leg_rotation_per_second:
       metrics.fastest_leg_rotation_at = "%s %s %.3f" % [clip_name, bone, time]
      metrics.max_leg_rotation_per_second = maxf(metrics.max_leg_rotation_per_second, speed)
     prior_rotations[bone] = rotation
   frames += 1
 expect(metrics.max_standing_stagger < 0.15, "standing feet close naturally instead of freezing a long stride")
 expect(metrics.max_standing_knee_bend < 40.0, "standing knees remain relaxed rather than crouching or lunging")
 expect(metrics.min_knee_forward > 0.7, "knees bend forward throughout the intro and waiting loop")
 expect(metrics.min_ankle_separation > 0.10, "feet do not cross the body's center line")
 expect(metrics.lowest_sole > -0.008, "skinned soles stay within 8 mm of the dock surface")
 expect(metrics.highest_support_sole < 0.025, "at least one real shoe stays on the dock throughout walking and casting")
 expect(metrics.closing_step_lift > 0.04, "closing step visibly lifts the trailing shoe")
 expect(metrics.closing_support_drift < 0.004, "support foot stays fixed while the trailing leg closes")
 expect(metrics.walk_contact_speed < 0.25, "planted walking toes do not skate across the deck")
 expect(metrics.max_leg_rotation_per_second < 14.0, "leg rotations remain continuous without knee or ankle snaps")
 print("LEG METRICS: ", JSON.stringify(metrics))
 var output := OS.get_environment("LAKEBOUND_QA_DIR")
 if not output.is_empty():
  DirAccess.make_dir_recursive_absolute(output)
  var file := FileAccess.open(output.path_join("leg_pose_metrics.json"), FileAccess.WRITE)
  file.store_string(JSON.stringify({"frames": frames, "metrics": metrics, "checks": checks, "failures": failures}, "  "))
 shoes.clear()
 bind_poses.clear()
 bind_bones.clear()
 scene.free()
 s = null
 await process_frame
 await process_frame
 await create_timer(0.3).timeout
 print("LOADING LEG POSE RESULT: %d sampled frames, %d checks, %d failures" % [frames, checks, failures])
 quit(0 if failures == 0 else 1)
