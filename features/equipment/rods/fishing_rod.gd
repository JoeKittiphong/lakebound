class_name FishingRodVisual
extends Node3D

## Rod scenes use +Y along the shaft; origin is the hand grip. Tip drives the line.
@export var bend_per_joint: float = 0.13
@onready var tip: Marker3D = $Joint1/Joint2/Joint3/Joint4/Joint5/Tip
@onready var joints: Array[Node3D] = [$Joint1, $Joint1/Joint2, $Joint1/Joint2/Joint3, $Joint1/Joint2/Joint3/Joint4, $Joint1/Joint2/Joint3/Joint4/Joint5]

func set_load(tension: float, side: float) -> void:
 for joint in joints:
  joint.rotation.x = -clampf(tension, 0.0, 1.0) * bend_per_joint
 $Joint1.rotation.z = -clampf(side, -1.0, 1.0) * 0.25
