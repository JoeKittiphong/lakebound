class_name FishModel
extends Node3D

@export_range(0.0, 0.5) var blend_seconds: float = 0.14
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
var current_clip: StringName = &""

func _ready() -> void:
 set_motion(&"roaming")

func set_motion(state: StringName, stamina: float = 1.0) -> void:
 var clip: StringName = &"swim"
 var speed := 0.72
 match state:
  &"resting", &"feeding", &"inspecting", &"biting":
   clip = &"hover"
   speed = 0.8
  &"landed":
   clip = &"hover"
   speed = 0.45
  &"fleeing", &"hunting":
   clip = &"fast_swim"
   speed = 1.10
  &"hooked":
   clip = &"fast_swim" if stamina > 0.25 else &"hover"
   speed = lerpf(0.55, 1.2, clampf(stamina, 0.0, 1.0))
  &"approaching":
   speed = 1.05
 if current_clip != clip:
  current_clip = clip
  animation_player.play(clip, blend_seconds)
 animation_player.speed_scale = speed

func set_active(value: bool) -> void:
 animation_player.active = value

func reset_phase(identity: int) -> void:
 animation_player.seek(fposmod(float(identity) * 0.618034, 1.0) * animation_player.current_animation_length, true)

func freeze_preview() -> void:
 set_motion(&"resting")
 animation_player.seek(0.0, true)
 set_active(false)
