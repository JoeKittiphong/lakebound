class_name FishSpecies
extends Resource

@export var id: StringName
@export var display_name: String = "ปลา"
@export var color := Color(0.45, 0.65, 0.52)
@export var model_scene: PackedScene
@export var collection_icon: Texture2D
@export_range(0.05, 3.0) var visual_length_m: float = 0.5
@export_range(0.0, 80.0) var preview_tilt_degrees: float = 12.0
@export var min_weight: float = 0.5
@export var max_weight: float = 2.0
@export var preferred_depth: Vector2 = Vector2(0.5, 2.5)
@export var bait_preferences := PackedStringArray(["worm"])
@export var detection_radius: float = 7.0
@export var swim_speed: float = 1.0
@export var pull_strength: float = 0.8
@export var struggle_frequency: float = 1.5
## Extra tension during surges; tune independently for each species.
@export_range(0.0, 0.3) var tension_pressure: float = 0.05
@export var body_scale := Vector3(1, 1, 1)

func fight_pressure(weight: float) -> float:
 var size_in_species := clampf((weight - min_weight) / maxf(max_weight - min_weight, 0.001), 0.0, 1.0)
 return tension_pressure * lerpf(0.8, 1.2, size_in_species)

func red_zone_start(weight: float) -> float:
 return fight_zones(weight, 1.0, 1.0).y

## X = yellow begins, Y = red begins. Fresh/surging fish leave a narrow
## yellow control window and more red than green; fatigue widens safe space.
func fight_zones(weight: float, stamina: float, activity: float) -> Vector2:
 var fresh := clampf(stamina, 0.0, 1.0)
 var surge := clampf((activity - 0.42) / 0.93, 0.0, 1.0)
 var red := clampf(lerpf(0.90, 0.54, fresh) - fresh * (surge * 0.06 + fight_pressure(weight) * 0.16), 0.42, 0.90)
 var difficulty := clampf(fight_pressure(weight) / 0.24, 0.0, 1.0)
 var width := (lerpf(0.14, 0.055, difficulty) + (1.0 - fresh) * 0.025) * 2.0
 if activity >= 1.5:
  # Leave room for a mobile-sized yellow band even during a hard surge.
  red = lerpf(0.40, 0.34, clampf((activity - 1.5) / 1.2, 0.0, 1.0))
  width *= 0.7
 width = maxf(0.18, width)
 var yellow := maxf(0.16, red - width)
 return Vector2(yellow, red)
