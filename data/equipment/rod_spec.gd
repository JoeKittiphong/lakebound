class_name RodSpec
extends Resource
## Game-authored specifications inspired by real product families, not manufacturer calibration.
@export var series: String = ""
@export var family: String = "spinning"
@export var length_m: float = 2.1
@export var handle_m: float = 0.42
@export_enum("UL", "L", "ML", "M", "MH", "H", "XH") var power: String = "M"
@export_enum("Slow", "Moderate", "Moderate-Fast", "Fast", "Extra-Fast") var action: String = "Moderate-Fast"
@export var sections: int = 2
@export var line_min_lb: float = 0.0
@export var line_max_lb: float = 0.0
@export var pe_max: float = 0.0
@export var lure_min_g: float = 0.0
@export var lure_max_g: float = 0.0
## Technique-specific envelopes. Negative means missing, never unlimited.
# Explicit packed default preserves authored values during Godot 4.7.2 export.
@export var techniques: PackedStringArray = PackedStringArray()
@export var cast_min_g := -1.0
@export var cast_max_g := -1.0
@export var jig_min_g := -1.0
@export var jig_max_g := -1.0
@export var drop_min_g := -1.0
@export var drop_max_g := -1.0
@export var pole_min_g := -1.0
@export var pole_max_g := -1.0
@export var max_working_drag_kgf := 2.0
@export var fly_weight := 0
## Total tangent rotation at full normalized visual load; separate from action distribution.
@export_range(0.2, 2.2) var bend_radians: float = 1.45
## High loads engage deeper sections without changing the rigid handle.
@export_range(0.0, 0.6) var progression: float = 0.22
@export_range(0.04, 0.6) var recovery_seconds: float = 0.14
@export_multiline var intended_use: String = ""
@export var reference_url: String = ""

static func exponent_for(value: String) -> float:
 return {"Slow": 0.25, "Moderate": 0.75, "Moderate-Fast": 1.6, "Fast": 3.2, "Extra-Fast": 5.0}.get(value, 1.6)

func joint_angles(load_value: float) -> PackedFloat32Array:
 return calculate_angles(action, bend_radians, progression, load_value)

static func calculate_angles(action_name: String, amplitude: float, progressive: float, load_value: float) -> PackedFloat32Array:
 var load_amount := clampf(load_value, 0.0, 1.0)
 var exponent := exponent_for(action_name)
 var deep_blend := progressive * smoothstep(0.45, 1.0, load_amount)
 var weights := PackedFloat32Array()
 var total := 0.0
 for i in 12:
  var t := (float(i) + 0.5) / 12.0
  var weight := lerpf(0.015 + pow(t, exponent), 0.015 + pow(t, 0.55), deep_blend)
  weights.append(weight)
  total += weight
 for i in 12:
  weights[i] = weights[i] / total * amplitude * load_amount
 return weights
