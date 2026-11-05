class_name TackleItem
extends Resource

@export var id: StringName
@export var display_name: String
@export var shop_icon: Texture2D
@export_multiline var description: String
@export var equipment_type: String = ""
@export_enum("bait", "lure", "rod", "reel", "line", "box", "boat") var kind := "bait"
@export var boat_spec: Resource
@export var price: int = 20
@export var quantity: int = 1
@export var bait_type: StringName = &"worm"
@export var strength: float = 5.0
## Swappable rod scene: origin at the grip, +Y along the shaft, Marker3D named Tip.
@export var model_scene: PackedScene
## Optional detailed rod specification shared with its authored model scene.
@export var rod_spec: RodSpec
@export var reel_spec: ReelSpec
@export var line_spec: LineSpec
## Lures include factory hooks/rings in ready-to-fish mass. Baits exclude rig mass.
@export var payload_g := -1.0
@export var attraction: BaitAttractionSpec
@export var terminal_rigs: Array[TerminalRigSpec] = []
@export_enum("none", "spinning", "casting", "overhead", "spincast", "fly", "ice", "fixed") var mount_layout: String = "none"
@export_enum("none", "spinning", "low", "round", "star", "lever", "spincast", "fly", "ice") var reel_family: String = "none"
@export_range(0.3, 2.0) var cast_multiplier: float = 1.0
@export_range(0.3, 1.5) var responsiveness: float = 1.0
@export_range(0.5, 1.5) var drag_power: float = 1.0
@export_enum("x", "y", "z") var spool_axis := "x"
@export_range(0.5, 1.5) var shock_absorption: float = 1.0
@export_range(0.5, 2.0) var visibility: float = 1.0
@export var length: float = 65.0
@export var reel_speed: float = 2.6
@export var capacity: float = 25.0
@export var recovery_cost: int = 2
@export_enum("float", "swim", "sink") var motion := "swim"
@export_enum("stop_and_go", "walk_the_dog", "twitch_pause", "jerk_fall", "steady") var lure_pattern := "stop_and_go"
@export_range(0.0, 2.0) var sink_speed: float = 0.45
## Negative means preserve selected depth; positive values make a plug dive on retrieve.
@export_range(-1.0, 8.0) var swim_depth: float = -1.0
@export_enum("auto", "Minnow", "Frog", "SoftPlastic", "Crank", "Popper", "Pencil", "Spoon", "Jig", "Spinner") var lure_visual := "auto"

## Shared material family; line mechanics keep the existing item stats.
@export_enum("mono", "fluoro", "braid", "fly") var line_visual_style: String = "mono"
