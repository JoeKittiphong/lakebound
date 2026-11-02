class_name RodControl
extends TouchJoystick

func set_battle_mode(value: bool) -> void:
 $Base.visible = true
 $Knob.visible = true
 $Directions.visible = value
 $Knob/HookIcon.visible = not value
