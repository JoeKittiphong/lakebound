class_name FishingHUD
extends Control

signal collection_visibility_changed(opened: bool)
signal action_requested
signal cancel_requested
signal keep_requested
signal release_requested
signal back_requested
signal aim_released
signal configuration_changed(bait: StringName, depth: float)

const F = preload("res://features/fishing/fishing_controller.gd")
const CAST_ICON = preload("res://assets/ui/modern/cast.svg")
const HOOK_ICON = preload("res://assets/ui/modern/hook.svg")
const BAIT_ICONS = [preload("res://assets/ui/modern/worm.svg"), preload("res://assets/ui/modern/dough.svg"), preload("res://assets/ui/modern/lure.svg")]
@onready var move_joystick: Control = $SafeArea/MoveJoystick
@onready var rod_joystick: RodControl = $SafeArea/RodJoystick
@onready var settings_panel: Control = $SafeArea/BaitPanel
@onready var meter: Control = $SafeArea/TensionMeter
var controller: FishingController
var ecology: PondEcosystem
var last_state: int = -1
var toast_time := 0.0
var last_feedback := ""
var ready_feedback := ""

func bind(fishing: FishingController, pond: PondEcosystem) -> void:
 controller = fishing
 ecology = pond
 last_feedback = controller.feedback
 ready_feedback = controller.feedback
 controller.state_changed.connect(_on_state_changed)
 ecology.population_changed.connect(_refresh_ecology)
 $CollectionPanel.opened.connect(func(): collection_visibility_changed.emit(true))
 $CollectionPanel.closed.connect(func(): collection_visibility_changed.emit(false))
 _on_state_changed()

func _on_state_changed() -> void:
 last_state = controller.state
 _refresh_state(last_state)

func rod_direction() -> Vector2:
 return rod_joystick.direction

func is_collection_open() -> bool:
 return $CollectionPanel.visible

func close_collection() -> void:
 $CollectionPanel.close()

func show_catch_result(fish: FishState, save_error: String) -> void:
 $ResultLayer.present(fish, save_error)

func _process(delta: float) -> void:
 if not is_instance_valid(controller):
  return
 var state: int = controller.state
 toast_time = maxf(0.0, toast_time - delta)
 $SafeArea/Toast.visible = toast_time > 0.0
 if controller.feedback != last_feedback:
  last_feedback = controller.feedback
  if state == F.State.READY and last_feedback != ready_feedback:
   _show_toast(last_feedback)
 var titles := ["", "รอปลา", "วัดเบ็ด!", "สู้ปลา", "", "ปลาหลุด", "เหวี่ยง"]
 $SafeArea/Status/Content/State.text = titles[state]
 if state == F.State.FIGHT:
  rod_joystick.show_reel(controller.rod_input, controller.tension > 0.82 and controller.drag_strength < 0.95)
  meter.value = controller.tension
  $SafeArea/TensionText.text = "%d%%" % int(controller.tension * 100)
  $SafeArea/TensionText.modulate = Color(1, 0.4, 0.35) if controller.tension >= 0.9 else Color.WHITE
  $SafeArea/LineInfo/Content/Distance.text = "%.1f m" % controller.line_length
  if controller.tension >= 0.9:
   $SafeArea/Status/Content/State.text = "↑ ผ่อนสาย"
  elif controller.tension < 0.15:
   $SafeArea/Status/Content/State.text = "↓ เก็บสาย"
 elif state == F.State.WAITING or state == F.State.BITE:
  $SafeArea/LineInfo/Content/Distance.text = "%.1f m" % controller.line_length

func _refresh_ecology() -> void:
 if $SafeArea/EcologyPanel.visible:
  var counts: Dictionary = ecology.counts()
  var lines := PackedStringArray()
  for index in range(0, ecology.species.size(), 2):
   var text: String = "%s %d" % [ecology.species[index].display_name, counts[ecology.species[index].id]]
   if index + 1 < ecology.species.size():
    text += "  •  %s %d" % [ecology.species[index + 1].display_name, counts[ecology.species[index + 1].id]]
   lines.append(text)
  $SafeArea/EcologyPanel/Content/Counts.text = "\n".join(lines)

func _refresh_state(state: int) -> void:
 toast_time = 0.0
 $SafeArea/Toast.hide()
 var battle := state == F.State.FIGHT
 var result := state == F.State.RESULT
 rod_joystick.set_battle_mode(battle)
 $SafeArea/CollectionButton.visible = state == F.State.READY
 settings_panel.hide()
 $SafeArea/BaitDock.visible = state == F.State.READY
 $SafeArea/Status.visible = state not in [F.State.READY, F.State.RESULT]
 $SafeArea/EcologyPanel.hide()
 $SafeArea/ActionButton.visible = state in [F.State.READY, F.State.BITE]
 $SafeArea/ActionButton.icon = HOOK_ICON if state == F.State.BITE else CAST_ICON
 $SafeArea/ActionButton.tooltip_text = "วัดเบ็ด" if state == F.State.BITE else "เหวี่ยงเบ็ด"
 $SafeArea/CancelButton.visible = state in [F.State.WAITING, F.State.BITE, F.State.FIGHT, F.State.CASTING]
 meter.visible = battle
 $SafeArea/TensionText.visible = battle
 $SafeArea/LineInfo.visible = state in [F.State.WAITING, F.State.BITE, F.State.FIGHT]
 rod_joystick.enabled = state in [F.State.READY, F.State.FIGHT]
 move_joystick.enabled = not result
 rod_joystick.modulate.a = 1.0 if rod_joystick.enabled else 0.35
 move_joystick.modulate.a = 0.35 if result else 1.0
 $ResultLayer.set_open(result)

func _on_rod_released() -> void:
 aim_released.emit()

func _on_action_pressed() -> void:
 action_requested.emit()

func _on_cancel_pressed() -> void:
 cancel_requested.emit()

func _on_keep_pressed() -> void:
 keep_requested.emit()

func _on_release_pressed() -> void:
 release_requested.emit()

func _on_back_pressed() -> void:
 back_requested.emit()

func _on_ecology_pressed() -> void:
 $SafeArea/EcologyPanel.visible = not $SafeArea/EcologyPanel.visible
 _refresh_ecology()

func _on_collection_pressed() -> void:
 if controller.state != F.State.READY:
  return
 rod_joystick.reset()
 move_joystick.reset()
 settings_panel.hide()
 $SafeArea/EcologyPanel.hide()
 $CollectionPanel.open()

func _on_config_changed(_value = 0) -> void:
 var bait_ids := [&"worm", &"dough", &"lure"]
 var depth: float = $SafeArea/BaitPanel/Content/DepthRow/Depth.value
 $SafeArea/BaitPanel/Content/DepthRow/Value.text = "%.1f ม." % depth
 $SafeArea/BaitDock/DepthButton.text = "%.1f" % depth
 var selected: int = $SafeArea/BaitPanel/Content/BaitRow/BaitSelect.selected
 $SafeArea/BaitDock/BaitButton.icon = BAIT_ICONS[selected]
 $SafeArea/BaitDock/BaitButton.tooltip_text = $SafeArea/BaitPanel/Content/BaitRow/BaitSelect.get_item_text(selected)
 configuration_changed.emit(bait_ids[$SafeArea/BaitPanel/Content/BaitRow/BaitSelect.selected], depth)

func _on_bait_pressed() -> void:
 if controller.state != F.State.READY:
  return
 var select: OptionButton = $SafeArea/BaitPanel/Content/BaitRow/BaitSelect
 select.select((select.selected + 1) % select.item_count)
 _on_config_changed()
 _show_toast(select.get_item_text(select.selected))

func _on_depth_pressed() -> void:
 if controller.state == F.State.READY:
  settings_panel.visible = not settings_panel.visible

func _show_toast(message: String) -> void:
 $SafeArea/Toast.text = message
 toast_time = 1.8
