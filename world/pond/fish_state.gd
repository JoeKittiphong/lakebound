class_name FishState
extends RefCounted

var id: int
var persistent_key: String = Crypto.new().generate_random_bytes(16).hex_encode()
var species: FishSpecies
var position := Vector3.ZERO # y is depth below water; positive metres.
var destination := Vector3.ZERO
var weight: float = 1.0
var hunger: float = 0.8
var stamina: float = 1.0
var caution: float = 0.0
var state: StringName = &"roaming"
var timer: float = 0.0
var surface_timer: float = 0.0
var decision_timer: float = 0.0
var heading: float = 0.0
