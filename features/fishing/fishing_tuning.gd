class_name FishingTuning
extends Resource

@export_range(0.01, 10.0) var cast_duration: float = 0.6
@export var reel_speed: float = 2.6
@export_range(0.5, 6.0) var yellow_retrieve_multiplier: float = 3.6
@export var release_speed: float = 3.6
@export var spool_capacity: float = 65.0
@export var break_grace: float = 1.4
@export var slack_grace: float = 2.5
@export var bite_window: float = 5.0
@export_range(0.2, 3.0) var retrieve_distance: float = 1.2
@export_range(20, 250) var red_haptic_duration_ms: int = 80
@export_range(0.15, 1.5) var red_haptic_interval: float = 0.45
