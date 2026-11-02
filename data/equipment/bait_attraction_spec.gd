class_name BaitAttractionSpec
extends Resource
## Game balancing values, not measured biological detection distances.
@export_range(1.0,15.0,.25) var radius_m:=4.5
@export_range(.05,2.0,.05) var visual_length_m:=.12
@export var model_rotation_degrees:=Vector3.ZERO
@export var attachment_offset:=Vector3.ZERO
@export_multiline var attraction_description:=""
