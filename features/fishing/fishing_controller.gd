class_name FishingController
extends Node

signal state_changed
signal bite_notified
signal fish_landed(fish: RefCounted)
signal fish_lost(reason: String)
signal cast_started

enum State { READY, WAITING, BITE, FIGHT, RESULT, LOST, CASTING }
@export var tuning: FishingTuning = preload("res://features/fishing/default_fishing_tuning.tres")
@export var ecosystem: PondEcosystem
@export var player: Node3D
@export var haptics_enabled := true
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
 if state != State.READY or not is_instance_valid(player):
  return false
 var target := get_aim_position()
 if target.distance_to(ecosystem.constrain_to_water(target)) > 0.05:
  feedback = "หันไปทางน้ำ แล้วเลือกจุดเหวี่ยงใหม่"
  return false
 cast_position = target
 line_length = Vector2(player.position.x - cast_position.x, player.position.z - cast_position.z).length()
 feedback = "กำลังเหวี่ยงเบ็ดไปยังจุดที่เลือก"
 _change_state(State.CASTING)
 cast_started.emit()
 return true

func get_aim_position() -> Vector3:
 var target: Vector3 = player.global_position + aim_offset.rotated(Vector3.UP, aim_yaw)
 target.y = selected_depth
 return target

func _on_fish_biting(record: RefCounted) -> void:
 if state != State.WAITING:
  return
 active_fish = record
 feedback = "ปลากินเบ็ด! กดวัดเบ็ด หรือกด Space"
 _change_state(State.BITE)
 # Notify only on a bite; no continuous battle vibration.
 if haptics_enabled and (OS.has_feature("android") or OS.has_feature("ios")):
  Input.vibrate_handheld(180)
 bite_notified.emit()

func strike() -> bool:
 if state != State.BITE or active_fish == null:
  return false
 ecosystem.hook(active_fish)
 fish_distance = _planar_distance(player.global_position, active_fish.position)
 line_length = fish_distance + 0.3
 tension = 0.45
 fight_time = 0.0
 overload_time = 0.0
 slack_time = 0.0
 rod_input = Vector2.ZERO
 feedback = "↓ ดึงปลา  ↑ ผ่อนสาย  ← → คุมคันเบ็ด"
 _change_state(State.FIGHT)
 return true

func advance(delta: float, angler_position: Vector3) -> void:
 state_time += delta
 if state == State.CASTING and state_time >= tuning.cast_duration:
  ecosystem.set_bait(cast_position, selected_bait)
  feedback = "รอปลาเข้าหาเหยื่อ… ดูทุ่นและผิวน้ำ"
  _change_state(State.WAITING)
 elif state == State.BITE and state_time > tuning.bite_window:
  lose("วัดเบ็ดไม่ทัน ปลาคายเหยื่อแล้ว")
 elif state == State.LOST and state_time > 2.8:
  reset_cast()
 elif state == State.FIGHT:
  _fight_step(delta, angler_position)

func _fight_step(delta: float, angler_position: Vector3) -> void:
 var stamina: float = active_fish.stamina
 fight.advance(delta, angler_position, active_fish, rod_input, tuning)
 active_fish.position = ecosystem.constrain_to_water(active_fish.position)
 fish_distance = _planar_distance(angler_position, active_fish.position)
 overload_time = overload_time + delta if tension >= 0.98 else maxf(0, overload_time - delta * 2.0)
 slack_time = slack_time + delta if tension < 0.12 else maxf(0, slack_time - delta * 2.0)
 if overload_time >= tuning.break_grace:
  lose("สายขาด! ครั้งหน้าผ่อนสายเมื่อแรงตึงขึ้นสีแดง")
 elif slack_time >= tuning.slack_grace:
  lose("สายหย่อนเกินไป ปลาสะบัดเบ็ดหลุด")
 elif fish_distance >= tuning.spool_capacity - 0.2:
  lose("สายหมดรอก ปลาหนีไปแล้ว")
 elif _within_landing_reach(angler_position) and stamina < 0.4 and tension > 0.15 and tension < 0.92:
  active_fish.state = &"landed"
  ecosystem.bait_active = false
  feedback = "จับปลาได้แล้ว!"
  _change_state(State.RESULT)
  fish_landed.emit(active_fish)

func lose(reason: String) -> void:
 ecosystem.cancel_bait()
 if active_fish != null:
  ecosystem.release(active_fish)
 active_fish = null
 rod_input = Vector2.ZERO
 feedback = reason
 _change_state(State.LOST)
 fish_lost.emit(reason)

func reset_cast() -> void:
 ecosystem.cancel_bait()
 active_fish = null
 rod_input = Vector2.ZERO
 tension = 0.0
 line_length = 0.0
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
 if keep_fish:
  ecosystem.keep(active_fish)
  kept_count += 1
 else:
  ecosystem.release(active_fish)
  released_count += 1
 reset_cast()

func _change_state(value: State) -> void:
 state = value
 state_time = 0.0
 state_changed.emit()

func _planar_distance(a: Vector3, b: Vector3) -> float:
 return Vector2(a.x - b.x, a.z - b.z).length()

func _within_landing_reach(angler_position: Vector3) -> bool:
 return ecosystem.can_land_fish(angler_position, active_fish.position, fish_distance)

func cast_progress() -> float:
 return clampf(state_time / maxf(tuning.cast_duration, 0.01), 0.0, 1.0)

