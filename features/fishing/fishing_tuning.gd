class_name FishingTuning
extends Resource

@export_range(0.01, 10.0) var cast_duration: float = 0.6
@export var reel_speed: float = 2.6
@export_group("Lure control")
@export_range(0.2, 0.9) var lure_gesture_threshold: float = 0.48
@export_range(0.08, 0.4) var lure_minimum_interval: float = 0.18
@export_range(0.4, 1.5) var lure_maximum_interval: float = 0.85
@export_range(0.1, 0.7) var lure_pause_duration: float = 0.28
@export_range(0.1, 2.0) var lure_twitch_distance: float = 0.6
@export_range(0.05, 1.0) var lure_jerk_depth: float = 0.25
@export_range(0.7, 1.5) var lure_beat_duration: float = 0.95
@export_range(1.0, 5.0) var lure_strike_window: float = 2.5
@export_range(0.0, 1.0) var lure_bite_chance: float = 0.78
@export_group("Fight")
@export_range(0.0, 1.0) var rod_steer_strength: float = 0.55
@export_range(0.5, 6.0) var yellow_retrieve_multiplier: float = 3.6
@export var release_speed: float = 3.6
@export var spool_capacity: float = 65.0
@export var break_grace: float = 1.4
@export var slack_grace: float = 2.5
@export var bite_window: float = 5.0
@export_range(0.2, 3.0) var retrieve_distance: float = 1.2
@export_range(20, 250) var red_haptic_duration_ms: int = 80
@export_range(0.15, 1.5) var red_haptic_interval: float = 0.45

@export_group("Fish health")
@export_range(1.0, 500.0) var fish_health_base: float = 60.0
@export_range(0.1, 1.0) var fish_health_weight_exponent: float = 0.35
@export_range(0.1, 100.0) var yellow_health_damage: float = 8.0
@export_range(0.1, 100.0) var red_health_damage: float = 11.0

@export_range(0.0, 2.0) var exhausted_landing_delay: float = 0.35
