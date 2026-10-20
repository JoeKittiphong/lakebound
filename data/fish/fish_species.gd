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
@export var body_scale := Vector3(1, 1, 1)
