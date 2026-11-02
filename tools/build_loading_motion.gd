extends SceneTree
## Offline authoring: bake cinematic-only poses into the editable scene Timeline.
## Run with --headless --path . --script res://tools/build_loading_motion.gd
const OUTPUT := "res://features/loading/cinematic/arrival_motion.tres"
const BONE_PATH := "ActorMotion/Angler/Asset/Scene/M2M_TPose_Rig/Skeleton3D:"
const LENGTH := 8.8
const WALK_START := 0.8
const WALK_END := 5.55
const STRIDE_END := 5.0
const CAST_START := 5.65
const RELEASE := 6.77
const LAND := 7.67
const WAIT := 8.0
const DISTANCE := 4.9
const CYCLE_DISTANCE := 1.06666666666667
const STRIDE_DISTANCE := CYCLE_DISTANCE * 4.45
const FPS := 60.0
var model: AnglerModel
var skeleton: Skeleton3D
var clips: Dictionary = {}
var rests: Array[Transform3D] = []
var settled_feet: Dictionary = {}
var starting_feet: Dictionary = {}
var stopping_feet: Dictionary = {}
var starting_pose: Array[Transform3D] = []
var toe_anchors := {}
var shoe_vertices: Array = []
var skin_bones: Array[int] = []
var skin_binds: Array[Transform3D] = []

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 model = load("res://actors/player/angler_model.tscn").instantiate()
 root.add_child(model)
 skeleton = model.skeleton
 for bone in skeleton.get_bone_count():
  rests.append(skeleton.get_bone_rest(bone))
 for name in ["Walk", "Fishing_Cast", "Fishing_Reel"]:
  clips[name] = model.animation_player.get_animation(name)
 model.animation_player.active = false
 model.locomotion_tree.active = false
 cache_shoe_geometry()
 for side in ["l", "r"]:
  var phase := 0.26 if side == "l" else 0.76
  apply_pose(sample("Walk", phase * clips["Walk"].length))
  toe_anchors[side] = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("ball_" + side)).origin
 # Establish a comfortable stance, and author a real closing step after walking.
 # Freezing the last stride leaves an unnaturally long, forced casting stance.
 var last_step := walk_pose(STRIDE_DISTANCE)
 var ready := sample("Fishing_Reel", 0.0)
 starting_pose = ready.duplicate()
 var carry := walk_pose(0.0)
 for name in ["clavicle_l", "upperarm_l", "lowerarm_l", "hand_l"]:
  var bone := skeleton.find_bone(name)
  starting_pose[bone] = carry[bone]
 apply_pose(ready)
 for side in ["l", "r"]:
  var foot := skeleton.find_bone("foot_" + side)
  starting_feet[side] = skeleton.get_bone_global_pose(foot)
 apply_pose(last_step)
 for side in ["l", "r"]:
  stopping_feet[side] = skeleton.get_bone_global_pose(skeleton.find_bone("foot_" + side))
 var right: Transform3D = starting_feet["r"]
 var right_world: Vector3 = skeleton.global_transform * stopping_feet["r"].origin
 right_world.y = (skeleton.global_transform * right.origin).y
 right_world.z += DISTANCE - STRIDE_DISTANCE
 right.origin = skeleton.to_local(right_world)
 settled_feet["r"] = right
 var left: Transform3D = starting_feet["l"]
 var left_world := skeleton.global_transform * left.origin
 left_world.z = right_world.z + 0.09
 left.origin = skeleton.to_local(left_world)
 settled_feet["l"] = left
 var library := AnimationLibrary.new()
 var arrival := Animation.new()
 arrival.resource_name = "arrival"
 arrival.length = LENGTH
 arrival.step = 1.0 / FPS
 var waiting := Animation.new()
 waiting.resource_name = "waiting"
 waiting.length = 4.8
 waiting.loop_mode = Animation.LOOP_LINEAR
 waiting.step = 1.0 / FPS
 add_bone_tracks(arrival)
 add_bone_tracks(waiting)
 for frame in int(round(LENGTH * FPS)) + 1:
  var time := float(frame) / FPS
  write_pose(arrival, time, ground_pose(arrival_pose(time)))
 for frame in int(round(waiting.length * FPS)) + 1:
  var time := float(frame) / FPS
  write_pose(waiting, time, ground_pose(waiting_pose(time)))
 add_value(arrival, "ActorMotion:position", func(t: float) -> Vector3: return Vector3(-2, 0.9, 5 - travel(t)))
 # Smooth camera start and finish, with no sudden velocity change at the waiting loop.
 add_value(arrival, "Camera3D:position", func(t: float) -> Vector3: return Vector3(6.5, 4.4, 9.5).lerp(Vector3(4.2, 3.4, 6.6), smoothstep(0.0, LENGTH, t)))
 add_value(arrival, "Camera3D:rotation", func(t: float) -> Vector3: return Vector3(-0.19278, 0.60323, 0).lerp(Vector3(-0.17149, 0.58364, 0), smoothstep(0.0, LENGTH, t)))
 add_value(arrival, "ActorMotion/Angler/RodHand/Grip:rotation", func(t: float) -> Vector3:
  # A small delayed wrist/rod recovery after the fast forward stroke.
  var bend := sin(clampf((t - 6.65) / 0.63, 0, 1) * TAU) * 0.028
  return Vector3(deg_to_rad(-24.6208) + bend, deg_to_rad(-1.484586), deg_to_rad(6.795397)))
 add_value(waiting, "ActorMotion:position", func(_t: float) -> Vector3: return Vector3(-2, 0.9, 5.0 - DISTANCE))
 add_value(waiting, "ActorMotion:rotation", func(_t: float) -> Vector3: return Vector3.ZERO)
 add_value(waiting, "ActorMotion/Angler/RodHand/Grip:rotation", func(_t: float) -> Vector3: return Vector3(deg_to_rad(-24.6208), deg_to_rad(-1.484586), deg_to_rad(6.795397)))
 var methods := arrival.add_track(Animation.TYPE_METHOD)
 arrival.track_set_path(methods, NodePath("."))
 for cue in [[WALK_START, "begin_walk"], [WALK_END, "finish_walk"], [CAST_START, "begin_cast"], [RELEASE, "release_line"], [LAND, "land_bobber"], [WAIT, "begin_wait"]]:
  arrival.track_insert_key(methods, float(cue[0]), {"method": StringName(cue[1]), "args": []})
 # Contact sounds follow the actual walk phase instead of an unrelated distance threshold.
 for step in 9:
  var contact := (float(step) + 0.12) * CYCLE_DISTANCE * 0.5
  var lo := WALK_START
  var hi := WALK_END
  for iteration in 24:
   var middle := (lo + hi) * 0.5
   if travel(middle) < contact:
    lo = middle
   else:
    hi = middle
  arrival.track_insert_key(methods, (lo + hi) * 0.5, {"method": &"footstep", "args": []})
 arrival.track_insert_key(methods, 5.0, {"method": &"footstep", "args": []})
 arrival.track_insert_key(methods, 5.49, {"method": &"footstep", "args": []})
 collapse_static_positions(arrival)
 collapse_static_positions(waiting)
 library.add_animation(&"arrival", arrival)
 library.add_animation(&"waiting", waiting)
 var error := ResourceSaver.save(library, OUTPUT)
 if error != OK:
  push_error("Cannot save cinematic animation library: %s" % error)
  quit(1)
  return
 var report := {"duration": LENGTH, "walk_start": WALK_START, "walk_end": WALK_END, "cast_start": CAST_START, "release": RELEASE, "landing": LAND, "wait": WAIT, "walk_distance": DISTANCE, "cycle_distance": CYCLE_DISTANCE, "arrival_tracks": arrival.get_track_count(), "baked_fps": FPS, "source_mesh_unchanged": true}
 DirAccess.make_dir_recursive_absolute("res://exports/qa-loading-motion")
 var file := FileAccess.open("res://exports/qa-loading-motion/authored_motion.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 print("LOADING MOTION BUILD RESULT: ", report)
 model.free()
 quit()

func travel(time: float) -> float:
 # Integral of a cosine ease-in/out velocity envelope (zero speed at both ends).
 if time >= STRIDE_END:
  return lerpf(STRIDE_DISTANCE, DISTANCE, smoothstep(STRIDE_END, WALK_END, time))
 var duration := STRIDE_END - WALK_START
 var ramp := 0.38
 var t := clampf(time - WALK_START, 0.0, duration)
 var integral: float
 if t < ramp:
  integral = 0.5 * (t - ramp / PI * sin(PI * t / ramp))
 elif t > duration - ramp:
  var remaining := duration - t
  integral = duration - ramp - 0.5 * (remaining - ramp / PI * sin(PI * remaining / ramp))
 else:
  integral = t - ramp * 0.5
 return STRIDE_DISTANCE * integral / (duration - ramp)

func sample(name: String, time: float) -> Array[Transform3D]:
 var pose: Array[Transform3D] = rests.duplicate()
 var clip: Animation = clips[name]
 for track in clip.get_track_count():
  var bone := skeleton.find_bone(clip.track_get_path(track).get_subname(0))
  if bone < 0:
   continue
  if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
   pose[bone].origin = clip.position_track_interpolate(track, time)
  elif clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
   pose[bone].basis = Basis(clip.rotation_track_interpolate(track, time))
 return pose

func blend(a: Array[Transform3D], b: Array[Transform3D], weight: float) -> Array[Transform3D]:
 var result: Array[Transform3D] = []
 for bone in a.size():
  result.append(a[bone].interpolate_with(b[bone], weight))
 return result

func walk_pose(distance: float) -> Array[Transform3D]:
 var clip: Animation = clips["Walk"]
 var pose := sample("Walk", fposmod(distance / CYCLE_DISTANCE, 1.0) * clip.length)
 var carry := sample("Fishing_Reel", 0.0)
 # Keep the right hand around the grip; retain the walk's pelvis/spine and left arm swing.
 for name in ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]:
  var bone := skeleton.find_bone(name)
  pose[bone] = pose[bone].interpolate_with(carry[bone], 0.94)
 apply_pose(pose)
 var targets := {}
 for side in ["l", "r"]:
  var foot := skeleton.get_bone_global_pose(skeleton.find_bone("foot_" + side))
  var toe := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("ball_" + side)).origin
  var offset := 0.08 if side == "l" else 0.58
  var cycle := floorf(distance / CYCLE_DISTANCE - offset)
  var phase := distance / CYCLE_DISTANCE - offset - cycle
  var contact := 1.0 - smoothstep(0.5, 0.6, phase)
  if phase > 0.94:
   cycle += 1.0
   contact = smoothstep(0.94, 1.0, phase)
  var anchor: Vector3 = toe_anchors[side]
  anchor.z += distance - (cycle + offset + 0.18) * CYCLE_DISTANCE
  var correction := Vector3(anchor.x - toe.x, 0, anchor.z - toe.z) * contact
  foot.origin += skeleton.global_basis.inverse() * correction
  var ankle_world := skeleton.global_transform * foot.origin
  # A modest foot clearance, instead of lifting the knee like a marching gait.
  var lower := maxf(0, ankle_world.y - 0.105) * 0.28
  foot.origin -= skeleton.global_basis.inverse() * Vector3.UP * lower
  targets[side] = foot
 return ground_pose(solve_targets(pose, targets))

func arrival_pose(time: float) -> Array[Transform3D]:
 if time < 1.35:
  return departure_pose(time)
 if time < STRIDE_END:
  return walk_pose(travel(time))
 var pose := blend(walk_pose(STRIDE_DISTANCE), sample("Fishing_Cast", cast_source_time(time)), smoothstep(STRIDE_END, WALK_END, time))
 if time < WALK_END:
  return closing_step_pose(pose, time)
 if time >= WAIT:
  return waiting_pose(0.0)
 if time >= 7.35:
  pose = blend(pose, sample("Fishing_Reel", 0.0), smoothstep(7.35, WAIT, time))
 return plant_feet(pose, 1.0)

func departure_pose(time: float) -> Array[Transform3D]:
 if time <= WALK_START:
  return starting_pose.duplicate()
 var walk := walk_pose(travel(time))
 apply_pose(walk)
 var targets := {}
 for side in ["l", "r"]:
  var current := skeleton.get_bone_global_pose(skeleton.find_bone("foot_" + side))
  var start: Transform3D = starting_feet[side]
  start.origin += skeleton.global_basis.inverse() * Vector3(0, 0, travel(time))
  var fraction := smoothstep(0.8, 1.05, time) if side == "l" else smoothstep(1.0, 1.3, time)
  var target := start.interpolate_with(current, fraction)
  if side == "l":
   target.origin += skeleton.global_basis.inverse() * Vector3.UP * sin(fraction * PI) * 0.045
  targets[side] = target
 var pose := blend(starting_pose, walk, smoothstep(0.8, 1.3, time))
 return solve_targets(pose, targets)

func closing_step_pose(pose: Array[Transform3D], time: float) -> Array[Transform3D]:
 var targets := {}
 var displacement := travel(time) - STRIDE_DISTANCE
 for side in ["l", "r"]:
  var anchor: Transform3D = stopping_feet[side]
  anchor.origin += skeleton.global_basis.inverse() * Vector3(0, 0, displacement)
  var end: Transform3D = settled_feet[side]
  # Fixed right support in world space while the hips finish moving forward.
  end.origin -= skeleton.global_basis.inverse() * Vector3(0, 0, DISTANCE - travel(time))
  var fraction := smoothstep(5.06, 5.49, time) if side == "l" else smoothstep(5.0, 5.15, time)
  var target := anchor.interpolate_with(end, fraction)
  if side == "l":
   target.origin += skeleton.global_basis.inverse() * Vector3.UP * sin(fraction * PI) * 0.065
  targets[side] = target
 return solve_targets(pose, targets)

func cast_source_time(time: float) -> float:
 # Preserve the original anticipation, accelerate the power stroke, let it follow through.
 var times := [CAST_START, 6.23, 6.52, 6.82, 7.12, 7.6]
 var samples := [0.0, 0.85, 1.18, 1.6, 1.95, 2.7]
 if time <= times[0]:
  return 0.0
 for index in times.size() - 1:
  if time <= times[index + 1]:
   return lerpf(samples[index], samples[index + 1], inverse_lerp(times[index], times[index + 1], time))
 return 2.7

func waiting_pose(time: float) -> Array[Transform3D]:
 var pose := sample("Fishing_Reel", 0.0)
 # Quiet hold rather than repeatedly winding the reel or rotating the planted actor root.
 var phase := TAU * time / 4.8
 var pelvis := skeleton.find_bone("pelvis")
 pose[pelvis].origin.y += sin(phase) * 0.3
 var chest := skeleton.find_bone("spine_03")
 pose[chest].basis = pose[chest].basis * Basis(Vector3.RIGHT, sin(phase) * 0.006)
 return plant_feet(pose, 1.0)

func apply_pose(pose: Array[Transform3D]) -> void:
 for bone in pose.size():
  skeleton.set_bone_pose_position(bone, pose[bone].origin)
  skeleton.set_bone_pose_rotation(bone, pose[bone].basis.get_rotation_quaternion())
 skeleton.force_update_all_bone_transforms()

func plant_feet(pose: Array[Transform3D], weight: float) -> Array[Transform3D]:
 apply_pose(pose)
 var targets := {}
 for side in ["l", "r"]:
  var current := skeleton.get_bone_global_pose(skeleton.find_bone("foot_" + side))
  targets[side] = current.interpolate_with(settled_feet[side], weight)
 return solve_targets(pose, targets)

func solve_targets(pose: Array[Transform3D], targets: Dictionary) -> Array[Transform3D]:
 apply_pose(pose)
 var lower_pelvis := 0.0
 # A staggered stance needs bent knees. Lower the hips before IK rather than
 # stretching a straight leg beyond its reach and letting the foot drift.
 for side in ["l", "r"]:
  var hip := skeleton.get_bone_global_pose(skeleton.find_bone("thigh_" + side)).origin
  var knee := skeleton.get_bone_global_pose(skeleton.find_bone("calf_" + side)).origin
  var ankle := skeleton.get_bone_global_pose(skeleton.find_bone("foot_" + side))
  var target: Transform3D = targets[side]
  var reach := (hip.distance_to(knee) + knee.distance_to(ankle.origin)) * 0.985
  var horizontal := Vector2(hip.x - target.origin.x, hip.z - target.origin.z).length()
  var height := sqrt(maxf(0.01, reach * reach - horizontal * horizontal))
  lower_pelvis = maxf(lower_pelvis, hip.y - target.origin.y - height)
 if lower_pelvis > 0.0:
  var pelvis := skeleton.find_bone("pelvis")
  var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(pelvis)).basis
  pose[pelvis].origin += parent.inverse() * Vector3(0, -lower_pelvis, 0)
  apply_pose(pose)
 for side in ["l", "r"]:
  var hip := skeleton.find_bone("thigh_" + side)
  var knee := skeleton.find_bone("calf_" + side)
  var ankle := skeleton.find_bone("foot_" + side)
  solve_leg(hip, knee, ankle, targets[side])
 var result: Array[Transform3D] = []
 for bone in pose.size():
  result.append(skeleton.get_bone_pose(bone))
 return result

func solve_leg(hip: int, knee: int, ankle: int, target: Transform3D) -> void:
 var start := skeleton.get_bone_global_pose(hip).origin
 var middle := skeleton.get_bone_global_pose(knee).origin
 var end := skeleton.get_bone_global_pose(ankle).origin
 var upper := start.distance_to(middle)
 var lower := middle.distance_to(end)
 var direction := (target.origin - start).normalized()
 var distance := clampf(start.distance_to(target.origin), absf(upper - lower) + 0.001, upper + lower - 0.001)
 var along := (upper * upper + distance * distance - lower * lower) / (2.0 * distance)
 var height := sqrt(maxf(0, upper * upper - along * along))
 # Stable anatomical bend plane: knees point forward with a small toe-out.
 # Reusing an almost straight source knee as the pole can flip it sideways.
 var side := 1.0 if skeleton.get_bone_name(hip).ends_with("_l") else -1.0
 var pole := Vector3(0.12 * side, 0, 1).slide(direction)
 var desired_knee := start + direction * along + pole.normalized() * height
 rotate_bone_toward(hip, middle - start, desired_knee - start)
 skeleton.force_update_all_bone_transforms()
 middle = skeleton.get_bone_global_pose(knee).origin
 end = skeleton.get_bone_global_pose(ankle).origin
 rotate_bone_toward(knee, end - middle, target.origin - middle)
 skeleton.force_update_all_bone_transforms()
 var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(ankle)).basis
 skeleton.set_bone_pose_rotation(ankle, (parent.inverse() * target.basis).get_rotation_quaternion())
 skeleton.force_update_all_bone_transforms()

func rotate_bone_toward(bone: int, from: Vector3, to: Vector3) -> void:
 var global := skeleton.get_bone_global_pose(bone)
 var rotated := Basis(Quaternion(from.normalized(), to.normalized())) * global.basis
 var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis
 skeleton.set_bone_pose_rotation(bone, (parent.inverse() * rotated).get_rotation_quaternion())

func add_bone_tracks(animation: Animation) -> void:
 for bone in skeleton.get_bone_count():
  var position := animation.add_track(Animation.TYPE_POSITION_3D)
  animation.track_set_path(position, NodePath(BONE_PATH + skeleton.get_bone_name(bone)))
  var rotation := animation.add_track(Animation.TYPE_ROTATION_3D)
  animation.track_set_path(rotation, NodePath(BONE_PATH + skeleton.get_bone_name(bone)))

func write_pose(animation: Animation, time: float, pose: Array[Transform3D]) -> void:
 for bone in pose.size():
  animation.position_track_insert_key(bone * 2, time, pose[bone].origin)
  animation.rotation_track_insert_key(bone * 2 + 1, time, pose[bone].basis.get_rotation_quaternion())

func add_value(animation: Animation, path: String, evaluate: Callable) -> void:
 var track := animation.add_track(Animation.TYPE_VALUE)
 animation.track_set_path(track, NodePath(path))
 for frame in int(round(animation.length * FPS)) + 1:
  var time := float(frame) / FPS
  animation.track_insert_key(track, time, evaluate.call(time))

func collapse_static_positions(animation: Animation) -> void:
 for track in animation.get_track_count():
  if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
   continue
  var first: Vector3 = animation.track_get_key_value(track, 0)
  var constant := true
  for key in animation.track_get_key_count(track):
   if not first.is_equal_approx(animation.track_get_key_value(track, key)):
    constant = false
    break
  if constant:
   for key in range(animation.track_get_key_count(track) - 1, 0, -1):
    animation.track_remove_key(track, key)

func cache_shoe_geometry() -> void:
 var body := skeleton.get_child(0) as MeshInstance3D
 for bind in body.skin.get_bind_count():
  skin_bones.append(skeleton.find_bone(body.skin.get_bind_name(bind)))
  skin_binds.append(body.skin.get_bind_pose(bind))
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
   var name := skeleton.get_bone_name(skin_bones[bind])
   if name.begins_with("foot_") or name.begins_with("ball_"):
    membership[String(name).right(1)] += weights[index]
  for side in ["l", "r"]:
   if membership[side] > 0.5:
    shoe_vertices.append({"side": side, "vertex": vertices[vertex], "bindings": bindings})

func ground_pose(pose: Array[Transform3D]) -> Array[Transform3D]:
 # Verify the skinned shoe, not just the ankle pivot. This is offline only.
 for iteration in 2:
  apply_pose(pose)
  var transforms: Array[Transform3D] = []
  for bind in skin_bones.size():
   transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(skin_bones[bind]) * skin_binds[bind])
  var heights := {"l": 100.0, "r": 100.0}
  for shoe in shoe_vertices:
   var position := Vector3.ZERO
   for binding in shoe.bindings:
    position += (transforms[binding[0]] * shoe.vertex) * binding[1]
   heights[shoe.side] = minf(heights[shoe.side], position.y)
  var targets := {}
  var correction_needed := false
  for side in ["l", "r"]:
   var foot := skeleton.get_bone_global_pose(skeleton.find_bone("foot_" + side))
   var lift := maxf(0, 0.001 - heights[side])
   correction_needed = correction_needed or lift > 0.0001
   foot.origin += skeleton.global_basis.inverse() * Vector3.UP * lift
   targets[side] = foot
  if not correction_needed:
   break
  pose = solve_targets(pose, targets)
 return pose
