class_name Pond
extends Node3D

@export var definition: PondDefinition = preload("res://world/pond/default_pond.tres")

func constrain_walking(point: Vector3) -> Vector3:
 return definition.constrain_walking(point)
