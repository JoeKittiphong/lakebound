extends Node3D

## Bounded spray pool; inputs use simulation coordinates (positive Y = depth).
@export_range(0.05, 0.5) var sample_interval := 0.15
@export_range(0.1, 0.8) var lure_surface_depth := 0.32
@export_range(0.1, 0.8) var fish_surface_depth := 0.45
@export_range(0.1, 1.0) var minimum_speed := 0.25
@export_range(0.15, 1.0) var tailbeat_interval := 0.3
@export_range(10.0, 70.0) var effect_distance := 45.0
var water_height := -0.18
var water_interactions: Node3D
var observer := Vector3.ZERO
var emitted_count := 0
var last_strength := 0.0
var _clock := 0.0
var _sample_clock := 0.0
var _lure_tracked := false
var _previous_lure := Vector3.ZERO
var _fish_samples: Dictionary = {}
var _available_at: Array[float] = []

func _ready() -> void:
 _available_at.resize(get_child_count())
 _available_at.fill(0.0)

func advance(delta: float, lure_position: Vector3, retrieving: bool, fish: Array, viewer: Vector3) -> void:
 _clock += delta
 _sample_clock += delta
 observer = viewer
 if not retrieving:
  _lure_tracked = false
  _fish_samples.clear()
 if _sample_clock < sample_interval: return
 var elapsed := _sample_clock
 _sample_clock = 0.0
 if not retrieving: return
 if _lure_tracked:
  var movement := lure_position - _previous_lure
  movement.y = 0.0
  var speed := movement.length() / elapsed
  if lure_position.y <= lure_surface_depth and speed >= minimum_speed and movement.length() < 3.0:
   emit_spray(lure_position, movement, clampf(speed * 0.25, 0.18, 0.65))
 _previous_lure = lure_position
 _lure_tracked = true
 var live := {}
 var bursts := 0
 for record in fish:
  if record.state not in [&"chasing_lure",&"committed"]: continue
  live[record.id] = true
  var previous: Dictionary = _fish_samples.get(record.id, {})
  var last_burst: float = previous.get("burst", -100.0)
  if not previous.is_empty():
   var movement: Vector3 = record.position - previous.position
   movement.y = 0.0
   var speed := movement.length() / elapsed
   if record.position.y <= fish_surface_depth and speed >= minimum_speed and movement.length() < 3.0 and _clock - last_burst >= tailbeat_interval and bursts < 2:
    var size_factor := clampf(sqrt(record.weight) * 0.3, 0.55, 1.3)
    var strength := clampf(speed * 0.4 * size_factor, 0.25, 1.3)
    if emit_spray(record.position, movement, strength):
     last_burst = _clock
     bursts += 1
  _fish_samples[record.id] = {"position":record.position, "burst":last_burst}
 for identity in _fish_samples.keys():
  if not live.has(identity): _fish_samples.erase(identity)

func strike(position_at_bite: Vector3, weight: float) -> void:
 if position_at_bite.y > fish_surface_depth: return
 emit_spray(position_at_bite, Vector3.ZERO, clampf(0.8 + sqrt(weight) * 0.15, 0.8, 1.5), true)

func emit_spray(point: Vector3, movement: Vector3, strength: float, priority: bool = false) -> bool:
 if Vector2(point.x - observer.x, point.z - observer.z).length_squared() > effect_distance * effect_distance: return false
 # Reserve the last emitter for bites so a busy pursuit never hides the strike.
 var first := get_child_count() - 1 if priority else 0
 var end := get_child_count() if priority else get_child_count() - 1
 for index in range(first, end):
  if not priority and _available_at[index] > _clock: continue
  var spray: CPUParticles3D = get_child(index)
  spray.global_position = Vector3(point.x, water_height + 0.045, point.z)
  var backward := -movement.normalized() * 0.65
  spray.direction = (Vector3.UP + backward).normalized()
  spray.amount = clampi(roundi(8 + strength * 14), 8, 30)
  spray.initial_velocity_min = 0.6 + strength * 0.8
  spray.initial_velocity_max = 1.2 + strength * 2.0
  spray.restart()
  spray.emitting = true
  _available_at[index] = _clock + spray.lifetime + 0.05
  emitted_count += 1
  last_strength = strength
  if is_instance_valid(water_interactions): water_interactions.emit_ripple(point, strength)
  return true
 return false
