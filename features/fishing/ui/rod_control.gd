class_name RodControl
extends TouchJoystick

func set_battle_mode(value: bool) -> void:
 $Base.visible = not value
 $Knob.visible = not value
 $Reel.visible = value

func show_reel(command: Vector2, slipping: bool) -> void:
 $Reel.command = command
 $Reel.slipping = slipping
