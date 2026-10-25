class_name TackleItem
extends Resource

@export var id: StringName
@export var display_name: String
@export_enum("bait", "lure", "rod", "reel", "line", "box") var kind := "bait"
@export var price: int = 20
@export var quantity: int = 1
@export var bait_type: StringName = &"worm"
@export var strength: float = 5.0
## Swappable rod scene: origin at the grip, +Y along the shaft, Marker3D named Tip.
@export var model_scene: PackedScene
@export_range(0.5, 2.0) var visibility: float = 1.0
@export var length: float = 65.0
@export var reel_speed: float = 2.6
@export var capacity: float = 25.0
@export var recovery_cost: int = 2
@export_enum("float", "swim", "sink") var motion := "swim"
