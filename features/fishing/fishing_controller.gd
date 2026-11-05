class_name FishingController
extends Node

signal state_changed
signal bite_notified
signal fish_landed(fish: RefCounted)
var bite_authorizer: Callable
var _bite_pending := false
var _bite_generation := 0
signal fish_lost(reason: String)
signal cast_started
signal haptic_requested(duration_ms: int)

enum State { READY, WAITING, BITE, FIGHT, RESULT, LOST, CASTING }
@export var tuning: FishingTuning = preload("res://features/fishing/default_fishing_tuning.tres")
@export var ecosystem: PondEcosystem
@export var player: Node3D
@export var haptics_enabled := true
var _red_haptic_cooldown: float = 0.0
var fight := FightSimulation.new()
var state: State = State.READY
var selected_bait: StringName = &"worm"
var selected_depth: float = 1.5
var aim_offset := Vector3(0, 0, -14)
var aim_yaw: float = 0.0
var cast_position := Vector3.ZERO
var active_fish: FishState
var rod_input := Vector2.ZERO
var tension: float:
 get:
  return fight.tension
 set(value):
  fight.tension = value
var line_length: float:
 get:
  return fight.line_length
 set(value):
  fight.line_length = value
var fish_distance: float = 0.0
var yellow_start: float:
 get:
  return fight.yellow_start
var red_start: float:
 get:
  return fight.red_start
var fish_force: float:
 get:
  return fight.fish_force
 set(value):
  fight.fish_force = value
var lateral_direction: float:
 get:
  return fight.lateral_direction
 set(value):
  fight.lateral_direction = value
var fight_time: float:
 get:
  return fight.fight_time
 set(value):
  fight.fight_time = value
var state_time: float = 0.0
var overload_time: float:
 get:
  return fight.overload_time
 set(value):
  fight.overload_time = value
var slack_time: float:
 get:
  return fight.slack_time
 set(value):
  fight.slack_time = value
var drag_strength: float:
 get:
  return fight.drag_strength
 set(value):
  fight.drag_strength = value
var feedback := "เลือกเหยื่อและความลึก แล้วเหวี่ยงเบ็ด"
var kept_count := 0
var released_count := 0
@export var map_id: String = "river"
var profile: AnglerProfile
var casting_enabled := true
var session_only_catches := false
var session_bait: TackleItem
var cast_bait_id := ""
var cast_terminal_rig:TerminalRigSpec
var catch_record: Dictionary = {}
var catch_event_id := ""
var bite_depth := 0.0
var bite_context: Dictionary = {}
var lure_input := LureInput.new()
var lure_gestures := preload("res://features/fishing/lure_gestures.gd").new()
var lure_rhythm := preload("res://features/fishing/lure_rhythm.gd").new()
var _rod_neutral_required := false
var lure_holding := false
var lure_action_name: StringName = &"release"

var _catch_collection: Node

func bind_profile(value: AnglerProfile, collection: Node = null) -> void:
 _catch_collection = collection
 profile = value
 tuning = tuning.duplicate()
 lure_input.action.connect(_on_lure_action)
 refresh_equipment()

func refresh_equipment() -> void:
 if profile == null:
  return
 profile.repair_equipment_fit()
 tuning.spool_capacity = minf(profile.data.line_remaining, profile.line_capacity())
 var rod: TackleItem = profile.equipped("rod")
 var reel: TackleItem = profile.equipped("reel")
 var line: TackleItem = profile.equipped("line")
 var bait: TackleItem = profile.equipped("bait")
 tuning.reel_speed = reel.reel_speed if reel != null else 0.0
 fight.line_strength = line.line_spec.break_kgf if line != null else 0.0
 fight.rod_strength = rod.strength if rod != null else 0.0
 fight.rod_responsiveness = rod.responsiveness if rod != null else 1.0
 fight.reel_drag_power = reel.drag_power if reel != null else 1.0
 fight.line_shock_absorption = line.shock_absorption if line != null else 1.0
 ecosystem.line_visibility = line.visibility if line != null else 1.0
 selected_bait = bait.bait_type if bait != null else &""
 if is_instance_valid(player) and player is AnglerPlayer:
  if rod == null: player.character_model.clear_rod()
  else: player.equip_rod(rod)
  player.character_model.equip_reel(profile.equipped("reel"))
  player.character_model.equip_line(profile.equipped("line"))

func active_bait_item()->TackleItem:
 if profile==null and session_bait!=null: return session_bait
 if not cast_bait_id.is_empty() and state in [State.CASTING,State.WAITING,State.BITE,State.FIGHT]:
  var entry:=TackleCatalog.item(cast_bait_id) as TackleItem
  if entry!=null:return entry
 return profile.equipped("bait") as TackleItem if profile!=null else null

func active_terminal_rig()->TerminalRigSpec:
 if cast_terminal_rig!=null and state in [State.CASTING,State.WAITING,State.BITE,State.FIGHT]:return cast_terminal_rig
 return profile.current_rig() if profile!=null else null

func using_lure() -> bool:
 var entry:=active_bait_item()
 return entry!=null and entry.kind=="lure"

func is_drop_method() -> bool:
 if profile == null: return false
 var rig := active_terminal_rig()
 return rig != null and rig.technique in ["vertical_jig", "boat_drop", "pole_float"]

func _ready() -> void:
 if is_instance_valid(ecosystem):
  ecosystem.fish_biting.connect(_on_fish_biting)

func _physics_process(delta: float) -> void:
 if is_instance_valid(player):
  advance(delta, player.global_position)

func set_aim(value: Vector2) -> void:
 if state != State.READY:
  return
 if value.length() > 0.1:
  var distance := lerpf(5.0, 23.0, value.length())
  aim_offset = Vector3(value.x * 0.8, 0, -1).normalized() * distance

func cast() -> bool:
 if not casting_enabled or state != State.READY or not is_instance_valid(player):
  return false
 var reason := cast_block_reason()
 if not reason.is_empty():
  feedback = reason
  return false
 var target := get_aim_position()
 if not ecosystem.definition.is_castable(target):
  feedback = "หันไปทางน้ำ แล้วเลือกจุดเหวี่ยงใหม่"
  return false
 if profile != null:
  refresh_equipment()
  target = get_aim_position()
  if tuning.spool_capacity < 1.0 or Vector2(_planar_distance(player.global_position, target), target.y).length() > tuning.spool_capacity:
   feedback = "เอ็นเหลือไม่พอถึงจุดนี้ — เปลี่ยนสายหรือเลือกจุดใกล้ขึ้น"
   return false
  if not profile.prepare_cast():
   feedback = profile.save_error if not profile.save_error.is_empty() else "เหยื่อหมด หรือมีเหยื่อรอกู้คืน — เปิดกระเป๋าอุปกรณ์"
   return false
  cast_bait_id = String(profile.equipped("bait").id)
  cast_terminal_rig=active_terminal_rig()
  if using_lure() and profile.equipped("bait").motion == "float":
   target.y = 0.12
 cast_position = target
 line_length = Vector2(player.position.x - cast_position.x, player.position.z - cast_position.z).length()
 var method := active_terminal_rig().technique if profile != null and active_terminal_rig() != null else "cast_float"
 feedback = "กำลังหย่อนชุดปลายสาย" if method in ["vertical_jig", "boat_drop", "pole_float"] else "กำลังเหวี่ยงเบ็ดไปยังจุดที่เลือก"
 _change_state(State.CASTING)
 cast_started.emit()
 return true

func cast_block_reason() -> String:
 if is_instance_valid(_catch_collection) and _catch_collection.recording_enabled and _catch_collection.incompatible_save:
  return "อ่านสมุดสะสมเดิมไม่ได้ — เก็บไฟล์เดิมไว้ กรุณาตรวจข้อมูลก่อนตกต่อ"
 if profile != null:
  if not profile.current_fit_error().is_empty():
   return profile.current_fit_error()
  if profile.incompatible:
   return "อ่านข้อมูลผู้เล่นไม่ได้ — ยังเหวี่ยงเบ็ดไม่ได้"
  if not profile.data.pending.is_empty():
   return "มีเหยื่อปลอมรอกู้คืน — เปิดกระเป๋าเพื่อกู้คืนหรือสละเหยื่อ"
  if profile.data.line_remaining < 1.0:
   return "เอ็นหมด — เปิดกระเป๋าอุปกรณ์เพื่อเปลี่ยนสายเอ็น"
  if profile.quantity(String(profile.equipped("bait").id)) <= 0:
   return "เหยื่อหมด — เปิดกระเป๋าเพื่อเปลี่ยนหรือซื้อเหยื่อ"
 if player is AnglerPlayer and not player.can_fish():
  return "กดตกปลาเพื่อหยุดเรือและยืนก่อนเหวี่ยงเบ็ด" if player.boat_driving() else "ขึ้นฝั่งและยืนให้มั่นก่อนเหวี่ยงเบ็ด"
 if is_instance_valid(player) and is_instance_valid(ecosystem):
  var target := get_aim_position()
  if not ecosystem.definition.is_castable(target):
   return "เหวี่ยงไม่ได้: หันไปทางน้ำ แล้วเลือกจุดเหวี่ยงใหม่"
 return ""

func get_aim_position() -> Vector3:
 if profile != null and profile.equipped("rod") == null:
  return player.global_position if is_instance_valid(player) else Vector3.ZERO
 var offset := aim_offset
 if profile != null:
  offset *= profile.equipped("rod").cast_multiplier
  var available := minf(profile.data.line_remaining, profile.line_capacity())
  # Reserve line for depth after finding the water depth at the aimed point.
  # Selected depth can exceed the remaining line after several breaks.
  # Never collapse the preview onto the angler when equipment needs replacing.
  if available >= 1.0:
   offset = offset.limit_length(available * 0.9)
  var rig := active_terminal_rig()
  if rig != null and rig.technique in ["vertical_jig", "boat_drop"]:
   offset = offset.limit_length(1.5)
  elif rig != null and rig.technique == "pole_float":
   offset = offset.limit_length(profile.equipped("rod").rod_spec.length_m * 0.85)
 var target: Vector3 = player.global_position + offset.rotated(Vector3.UP, aim_yaw)
 target.y = selected_depth
 if is_instance_valid(ecosystem):
  var available: float = ecosystem.definition.water_depth_at(Vector2(target.x, target.z))
  target.y = minf(target.y, maxf(0.1, available - 0.14))
 if profile != null:
  var available := minf(profile.data.line_remaining, profile.line_capacity())
  var planar := _planar_distance(player.global_position, target)
  if available >= 1.0:
   target.y = minf(target.y, sqrt(maxf(0.01, available * available - planar * planar)) * 0.98)
 return target

func _on_fish_biting(record: RefCounted) -> void:
 if state != State.WAITING or _bite_pending:
  return
 if bite_authorizer.is_valid():
  var generation := _bite_generation
  _bite_pending=true
  feedback="กำลังยืนยันปลากินเบ็ด…"
  var allowed: bool=await bite_authorizer.call(record)
  if generation!=_bite_generation: return
  _bite_pending=false
  if state!=State.WAITING: return
  if not allowed:
   ecosystem.release(record)
   feedback="ยังยืนยันปลาตัวนี้ไม่ได้ · รอปลาตัวอื่น"
   return
 active_fish = record
 catch_event_id = Crypto.new().generate_random_bytes(16).hex_encode()
 bite_depth = cast_position.y
 # Freeze the bait and angler at the bite, before either moves during the fight.
 bite_context = {}
 if is_instance_valid(player):
  bite_context = {"angler_xz": Vector2(player.global_position.x, player.global_position.z),
   "bite_xz": Vector2(cast_position.x, cast_position.z),
   "from_boat": player is AnglerPlayer and player.boat != null}
 feedback = "ปลากินเบ็ด! ปล่อยจอยแล้วดึงลงเพื่อวัดเบ็ด"
 tension = 0.13
 _change_state(State.BITE)
 _request_haptic(180)
 bite_notified.emit()

func strike() -> bool:
 if state != State.BITE or active_fish == null:
  return false
 ecosystem.hook(active_fish)
 fish_distance = _planar_distance(player.global_position, active_fish.position)
 line_length = fish_distance + 0.3
 tension = 0.13
 fight_time = 0.0
 fight.begin(active_fish, tuning)
 fight.update_zones(active_fish)
 tension = 0.13
 overload_time = 0.0
 slack_time = 0.0
 _rod_neutral_required = _rod_neutral_required or rod_input.length() > 0.1
 rod_input = Vector2.ZERO
 feedback = "↓ ดึงปลา  ↑ ผ่อนสาย  ← → คุมคันเบ็ด"
 _change_state(State.FIGHT)
 return true

func advance(delta: float, angler_position: Vector3) -> void:
 state_time += delta
 if _rod_neutral_required:
  if rod_input.length() < 0.1:
   _rod_neutral_required = false
  rod_input = Vector2.ZERO
 if using_lure() and state == State.WAITING:
  lure_input.advance(delta)
  _lure_step(delta)
 if state == State.CASTING and state_time >= tuning.cast_duration:
  ecosystem.set_bait(cast_position, active_bait_item().bait_type if active_bait_item()!=null else selected_bait, using_lure(), active_bait_item())
  feedback = "รอปลาเข้าหาเหยื่อ… ดูทุ่นและผิวน้ำ"
  _change_state(State.WAITING)
 elif state == State.BITE and state_time > tuning.bite_window:
  lose("วัดเบ็ดไม่ทัน ปลาคายเหยื่อแล้ว")
 elif state == State.BITE and rod_input.y > 0.1:
  strike()
 elif state == State.WAITING:
  _retrieve_step(delta, angler_position)
 elif state == State.LOST and state_time > 2.8:
  reset_cast()
 elif state == State.FIGHT:
  _fight_step(delta, angler_position)

func _retrieve_step(delta: float, angler_position: Vector3) -> void:
 if active_fish != null or ecosystem.reserved_fish != null:
  return
 var reel := maxf(0.0, rod_input.y)
 var rig := active_terminal_rig() if profile != null else null
 if rig != null and rig.technique in ["vertical_jig", "boat_drop"]:
  var depth_limit := ecosystem.definition.water_depth_at(Vector2(cast_position.x, cast_position.z)) - 0.14
  var radial := _planar_distance(angler_position, cast_position)
  depth_limit = minf(depth_limit, sqrt(maxf(0.0, tuning.spool_capacity * tuning.spool_capacity - radial * radial)))
  var payout := maxf(0.0, -rod_input.y) if not using_lure() else 0.0
  cast_position.y = clampf(cast_position.y - reel * tuning.reel_speed * delta + payout * tuning.release_speed * delta, 0.05, maxf(0.05, depth_limit))
  line_length = Vector2(radial, cast_position.y).length()
  ecosystem.move_bait(cast_position)
  if reel > 0.0 and cast_position.y <= 0.15:
   reset_cast()
   feedback = "เก็บชุดปลายสายขึ้นแล้ว"
  return
 var release_line := 0.0 if using_lure() else maxf(0.0, -rod_input.y)
 line_length = clampf(line_length - reel * tuning.reel_speed * delta + release_line * tuning.release_speed * delta, 0.0, tuning.spool_capacity)
 var distance := _planar_distance(angler_position, cast_position)
 # Payout creates slack; winding takes up slack before moving the bait.
 if reel > 0.0 and distance > line_length:
  var direction := Vector2(cast_position.x - angler_position.x, cast_position.z - angler_position.z).normalized()
  var point := Vector3(angler_position.x + direction.x * line_length, cast_position.y, angler_position.z + direction.y * line_length)
  cast_position = ecosystem.constrain_to_water(point)
  ecosystem.move_bait(cast_position)
 var edge := ecosystem.constrain_to_water(angler_position)
 if _planar_distance(cast_position, edge) <= tuning.retrieve_distance:
  reset_cast()
  feedback = "เก็บเหยื่อกลับแล้ว เล็งเพื่อเหวี่ยงใหม่"

func _fight_step(delta: float, angler_position: Vector3) -> void:
 fight.advance(delta, angler_position, active_fish, rod_input, tuning)
 active_fish.position = ecosystem.constrain_to_water(active_fish.position)
 fish_distance = _planar_distance(angler_position, active_fish.position)
 # End-of-spool load is included in the simulation before payout input.
 # Never overwrite the player's recovered tension after simulating controls.
 # Red is a control cue, not a breaking-strength measurement. A strong line
 # must never snap under a light fish solely because the UI stayed in red.
 overload_time = overload_time + delta if fight.line_load_kgf >= fight.line_strength else maxf(0, overload_time - delta * 2.0)
 slack_time = slack_time + delta if tension < 0.12 and not fight.exhausted else maxf(0, slack_time - delta * 2.0)
 if overload_time >= tuning.break_grace:
  lose("สายขาด! แรงดึงเกินสเปคเอ็น — ผ่อนสายหรือใช้เอ็นที่รับแรงได้มากขึ้น", true)
 elif slack_time >= tuning.slack_grace:
  lose("สายหย่อนเกินไป ปลาสะบัดเบ็ดหลุด")
 elif _within_landing_reach(angler_position) and fight.exhausted and fight.exhausted_time >= tuning.exhausted_landing_delay and rod_input.y > 0.1:
  active_fish.state = &"landed"
  ecosystem.bait_active = false
  feedback = "จับปลาได้แล้ว!"
  _change_state(State.RESULT)
  fish_landed.emit(active_fish)
 _update_tension_haptics(delta)

func _request_haptic(duration_ms: int) -> void:
 if not haptics_enabled:
  return
 haptic_requested.emit(duration_ms)
 if OS.has_feature("android") or OS.has_feature("ios"):
  Input.vibrate_handheld(duration_ms)

func _update_tension_haptics(delta: float) -> void:
 _red_haptic_cooldown = maxf(0.0, _red_haptic_cooldown - delta)
 if not haptics_enabled or state != State.FIGHT or active_fish == null:
  return
 if not fight.exhausted and tension >= red_start and _red_haptic_cooldown <= 0.0:
  _request_haptic(tuning.red_haptic_duration_ms)
  _red_haptic_cooldown = tuning.red_haptic_interval

func lose(reason: String, line_broken: bool = false) -> void:
 if line_broken and profile != null:
  if not profile.break_line(line_length, cast_bait_id):
   reason += " • " + profile.save_error
 ecosystem.cancel_bait()
 if active_fish != null:
  ecosystem.release(active_fish)
 active_fish = null
 rod_input = Vector2.ZERO
 feedback = reason
 _change_state(State.LOST)
 fish_lost.emit(reason)

func reset_cast() -> void:
 _bite_generation+=1
 _bite_pending=false
 ecosystem.cancel_bait()
 active_fish = null
 catch_event_id = ""
 catch_record = {}
 bite_context = {}
 rod_input = Vector2.ZERO
 cast_bait_id = ""
 cast_terminal_rig=null
 tension = 0.0
 line_length = 0.0
 lure_input.reset()
 lure_holding = false
 feedback = "เลือกเหยื่อและความลึก แล้วเหวี่ยงเบ็ด"
 _change_state(State.READY)

func cancel() -> void:
 if state == State.RESULT:
  resolve_catch(false)
 elif active_fish != null:
  ecosystem.release(active_fish)
  reset_cast()
 else:
  reset_cast()

func resolve_catch(keep_fish: bool) -> void:
 if state != State.RESULT:
  return
 # Retry the same immutable landed event after a save failure, before allowing
 # the result screen to discard it. Successful events are idempotent.
 if profile != null and not session_only_catches and catch_record.has("catch_id"):
  if is_instance_valid(_catch_collection):
   var result := CatchSettlement.persist(profile, _catch_collection, catch_record)
   if not result.saved:
    feedback = result.error
    return
  elif not profile.record_catch(catch_record, bool(catch_record.get("boss", false)), false):
   feedback = profile.save_error
   return
 if keep_fish:
  if profile != null and not session_only_catches:
   var population := ecosystem.snapshot()
   for index in range(population.size() - 1, -1, -1):
    if population[index].id == active_fish.id:
     population.remove_at(index)
   var stored_record := catch_record.duplicate(true)
   for entry in ecosystem.snapshot():
    if entry.id == active_fish.id:
     stored_record["fish_snapshot"] = entry.duplicate(true)
     break
   if not profile.keep_catch(stored_record, map_id, population):
    feedback = profile.save_error if not profile.save_error.is_empty() else "กล่องปลาเต็ม — ขายปลาในกระเป๋าหรือปล่อยตัวนี้"
    return
  ecosystem.keep(active_fish)
  kept_count += 1
 else:
  ecosystem.release(active_fish)
  released_count += 1
 reset_cast()

func _change_state(value: State) -> void:
 if value != state:
  _rod_neutral_required = _rod_neutral_required or rod_input.length() > 0.1
  rod_input = Vector2.ZERO
  lure_gestures.reset()
  lure_rhythm.reset()
  if is_instance_valid(ecosystem):
   ecosystem.lure_appeal = 0.0
   ecosystem.invalidate_lure_action()
 if value != State.WAITING:
  lure_input.reset()
  lure_holding = false
 if value != State.FIGHT:
  _red_haptic_cooldown = 0.0
  if state == State.FIGHT and haptics_enabled and (OS.has_feature("android") or OS.has_feature("ios")):
   Input.vibrate_handheld(0)
 state = value
 if value == State.WAITING and is_instance_valid(ecosystem):
  ecosystem.lure_controlled = using_lure()
 state_time = 0.0
 state_changed.emit()

func _planar_distance(a: Vector3, b: Vector3) -> float:
 return Vector2(a.x - b.x, a.z - b.z).length()

func _within_landing_reach(angler_position: Vector3) -> bool:
 return ecosystem.can_land_fish(angler_position, active_fish.position, fish_distance)

func cast_progress() -> float:
 return clampf(state_time / maxf(tuning.cast_duration, 0.01), 0.0, 1.0)

func _on_lure_action(action: StringName) -> void:
 if state != State.WAITING or not using_lure():
  return
 lure_action_name = action
 lure_holding = action == &"hold"
 if action in [&"tap", &"double_tap"]:
  _move_lure(0.35 if action == &"tap" else 0.85, -0.25)

func _lure_step(delta: float) -> void:
 if ecosystem.reserved_fish != null:
  return
 lure_gestures.threshold = tuning.lure_gesture_threshold
 lure_gestures.minimum_interval = tuning.lure_minimum_interval
 lure_gestures.maximum_interval = tuning.lure_maximum_interval
 lure_gestures.pause_duration = tuning.lure_pause_duration
 var gesture: Dictionary = lure_gestures.advance(delta, rod_input, active_bait_item().lure_pattern)
 var rhythm: Dictionary = lure_rhythm.advance(delta, rod_input, active_bait_item().lure_pattern, String(active_bait_item().id))
 if rhythm.mistake:
  ecosystem.invalidate_lure_action()
 if rhythm.accepted:
  ecosystem.register_lure_action(rhythm.quality)
 if gesture.jerk:
  _move_lure(0.35, -tuning.lure_jerk_depth)
 if gesture.side != 0 and not is_drop_method():
  var toward := Vector2(player.global_position.x - cast_position.x, player.global_position.z - cast_position.z).normalized()
  # Fight simulation and lure control share the line-relative lateral frame.
  cast_position.x += toward.y * float(gesture.side) * tuning.lure_twitch_distance
  cast_position.z -= toward.x * float(gesture.side) * tuning.lure_twitch_distance
  _move_lure(0.12, 0.0)
 if not gesture.pattern.is_empty():
  ecosystem.lure_appeal = 0.2
 var bait: Resource = active_bait_item()
 var motion: String = bait.motion
 if bait.swim_depth > 0.0 and rod_input.y > 0.1:
  _move_lure(0.0, move_toward(cast_position.y, bait.swim_depth, delta * rod_input.y) - cast_position.y)
 if lure_holding:
  _move_lure(tuning.reel_speed * 0.4 * delta, 0.0)
 elif motion == "sink":
  _move_lure(0.0, delta * bait.sink_speed)
 elif motion == "float":
  cast_position.y = 0.12
  ecosystem.move_bait(cast_position)
 # A full formula cannot stay banked at an empty or unsuitable spot.
 # Recheck after moving the lure, including while waiting on a full meter.
 if lure_rhythm.progress() >= 1.0 and not ecosystem.has_lure_candidate():
  ecosystem.invalidate_lure_action()
  lure_rhythm.retry_without_fish()

func _move_lure(retrieve: float, depth_change: float) -> void:
 if ecosystem.reserved_fish != null:
  return
 var toward := Vector2(player.global_position.x - cast_position.x, player.global_position.z - cast_position.z).normalized()
 var vertical := active_terminal_rig() != null and active_terminal_rig().technique == "vertical_jig"
 if vertical: retrieve = 0.0
 cast_position.x += toward.x * retrieve
 cast_position.z += toward.y * retrieve
 var max_depth := ecosystem.definition.water_depth_at(Vector2(cast_position.x, cast_position.z))
 if vertical:
  var radial := _planar_distance(player.global_position, cast_position)
  max_depth = minf(max_depth, sqrt(maxf(0.0, tuning.spool_capacity * tuning.spool_capacity - radial * radial)))
 cast_position.y = clampf(cast_position.y + depth_change, 0.12, maxf(0.12, max_depth - 0.14))
 if active_bait_item().motion == "float":
  cast_position.y = 0.12
 cast_position = ecosystem.constrain_to_water(cast_position)
 line_length = Vector2(_planar_distance(player.global_position, cast_position), cast_position.y).length() if vertical else minf(line_length, _planar_distance(player.global_position, cast_position))
 ecosystem.move_bait(cast_position)

