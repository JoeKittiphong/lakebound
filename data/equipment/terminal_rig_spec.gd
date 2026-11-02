class_name TerminalRigSpec
extends Resource
## Mass of bait is stored on the item; these are additional rig components.
@export var id: StringName
@export var display_name := ""
@export_enum("cast_float", "cast_bottom", "cast_retrieve", "pole_float", "vertical_jig", "boat_drop", "fly_cast", "ice_drop") var technique := "cast_float"
@export var hook_g := 0.0
@export var sinker_g := 0.0
@export var float_g := 0.0
@export var feeder_g := 0.0
@export var bait_fill_g := 0.0
@export var fittings_g := 0.0
@export var swivel := false
@export_enum("mono", "fluoro", "braid", "coated_mono", "fly") var leader_material := "mono"
@export var leader_length_m := 0.3

func extra_mass_g() -> float:
 return hook_g + sinker_g + float_g + feeder_g + bait_fill_g + fittings_g

func valid() -> bool:
 for value in [hook_g, sinker_g, float_g, feeder_g, bait_fill_g, fittings_g, leader_length_m]:
  if not is_finite(value) or value < 0.0: return false
 return not str(id).is_empty()
