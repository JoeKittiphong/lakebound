extends Node3D

## Short delayed interpolation with bounded prediction during packet gaps.
@export_range(0.0, 0.5) var interpolation_delay := 0.18
@export_range(0.0, 1.0) var prediction_limit := 0.45
@export_range(0.05, 1.0) var correction_time := 0.12
@export_range(1.0, 100.0) var teleport_distance := 30.0
@export_range(3.0, 30.0) var stale_timeout := 10.0
var target_position := Vector3.ZERO
var target_yaw := 0.0
var speed := 0.0
var state := 0
var age := 0.0
var _clock := 0.0
var _samples: Array[Dictionary] = []
var _correction := Vector3.ZERO
var _previous_state := 0
var _trace_lines := 0
var _trace_at := -1.0
@onready var model: AnglerModel = $Visual/AnglerModel

func apply_pose(pose: Dictionary, display_name: String) -> void:
 var point := Vector3(float(pose.p[0]), float(pose.p[1]), float(pose.p[2]))
 var reset := _samples.is_empty() or age >= stale_timeout or global_position.distance_to(point) > teleport_distance
 var gap := age
 target_position = point
 target_yaw = float(pose.yaw)
 var reported_speed := float(pose.speed)
 var velocity := Vector3(-sin(target_yaw),0,-cos(target_yaw))*reported_speed
 if pose.has("v"):
  velocity=Vector3(float(pose.v[0]),0,float(pose.v[1])).limit_length(reported_speed)
 var sample := {"time":_clock,"p":point,"yaw":target_yaw,"v":velocity,"speed":reported_speed,"state":int(pose.state)}
 if reset:
  _samples.clear()
  global_position=point
  rotation.y=target_yaw
  _correction=Vector3.ZERO
 else:
  # Coalesce bursts with identical receipt times; never divide by zero.
  if is_equal_approx(float(_samples.back().time),_clock): _samples.pop_back()
 _samples.append(sample)
 while _samples.size()>16: _samples.pop_front()
 if not reset: _correction=global_position-(_sample_at(_clock-interpolation_delay).p as Vector3)
 if OS.get_environment("LAKEBOUND_MOTION_DEBUG")=="1" and _trace_lines<300 and _clock-_trace_at>=1.0:
  print("MOTION_RX gap_s=",snappedf(gap,0.001)," correction_m=",snappedf(_correction.length(),0.001)," speed=",snappedf(reported_speed,0.01)," reset=",reset)
  _trace_at=_clock
  _trace_lines+=1
 age=0.0
 $Name.text=display_name
 visible=true

func _sample_at(playback: float) -> Dictionary:
 var a: Dictionary=_samples[0]
 if playback<=float(a.time): return {"p":a.p,"yaw":a.yaw,"speed":0.0,"state":a.state}
 for index in range(1,_samples.size()):
  var b: Dictionary=_samples[index]
  if playback<float(b.time):
   var blend:=clampf((playback-float(a.time))/maxf(float(b.time)-float(a.time),0.0001),0.0,1.0)
   return {"p":(a.p as Vector3).lerp(b.p,blend),"yaw":lerp_angle(float(a.yaw),float(b.yaw),blend),"speed":lerpf(float(a.speed),float(b.speed),blend),"state":a.state}
  a=b
 var elapsed:=maxf(0.0,playback-float(a.time))
 return {"p":(a.p as Vector3)+(a.v as Vector3)*minf(elapsed,prediction_limit),"yaw":a.yaw,"speed":float(a.speed) if elapsed<prediction_limit else 0.0,"state":a.state}

func _process(delta: float) -> void:
 _clock+=delta
 age+=delta
 visible=not _samples.is_empty() and age<stale_timeout
 if _samples.is_empty(): return
 var rendered:=_sample_at(_clock-interpolation_delay)
 _correction*=exp(-delta/maxf(correction_time,0.001))
 global_position=(rendered.p as Vector3)+_correction
 rotation.y=lerp_angle(rotation.y,float(rendered.yaw),1.0-exp(-12.0*delta))
 speed=float(rendered.speed)
 state=int(rendered.state)
 if state==6 and _previous_state!=6: model.cast(0.6)
 _previous_state=state
 model.update_motion(delta,speed>0.1,speed,false,false,false,speed>4.0)
 model.set_fishing_state(state,0.5 if state==3 else 0.0,0.4 if state==3 else 0.0)
