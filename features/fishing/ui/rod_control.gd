class_name RodControl
extends TouchJoystick

func set_battle_mode(value: bool) -> void:
 $Base.visible = not value
 $Knob.visible = not value
 $Reel.visible = value

func show_reel(command: Vector2, slipping: bool) -> void:
 $Reel.command = command
 $Reel.slipping = slipping

func reel_guide_position() -> Vector2:
 return $Reel.line_guide_screen_position()
