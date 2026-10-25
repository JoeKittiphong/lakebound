class_name FishingHUD
extends Control

signal collection_visibility_changed(opened: bool)
signal keep_requested
signal release_requested
signal back_requested
signal aim_released
signal orbit_requested(held: bool)
signal orbit_dragged(horizontal_motion: float)
signal jump_requested
signal greet_requested
signal run_toggled(enabled: bool)
signal boat_action_requested
signal boat_exit_requested
signal configuration_changed(bait: StringName, depth: float)

const F = preload("res://features/fishing/fishing_controller.gd")
const BAIT_ICONS = [preload("res://assets/ui/atlas/icon_worm.tres"), preload("res://assets/ui/atlas/circle_mint.tres"), preload("res://assets/ui/atlas/icon_hook.tres")]
@onready var move_joystick: Control = $SafeArea/MoveJoystick
@onready var rod_joystick: RodControl = $SafeArea/RodJoystick
@onready var settings_panel: Control = $SafeArea/BaitPanel
@onready var meter: Control = $SafeArea/TensionMeter
@onready var _modal_panels: Array[Control] = [$CollectionPanel, $TacklePanel, $MissionPanel]
var _modal_reported := false
var controller: FishingController
var ecology: PondEcosystem
var last_state: int = -1
var _aim_gesture := false
var _can_cast := true
var _on_boat := false
var toast_time := 0.0
var last_feedback := ""
var ready_feedback := ""
var pending_mission_completions: Array[String] = []
var mission_toast_time := 0.0
@export var tension_reel_gap: float = 24.0

func _ready() -> void:
 # HUD owns its panels. Session receives only aggregate modal transitions so
 # closing one panel cannot unpause another panel that is still open.
 for panel in _modal_panels:
  panel.connect("opened", _on_modal_changed)
  panel.connect("closed", _on_modal_changed)

func configure_session(region_id: String, depth_limit: float) -> void:
 $SafeArea/BaitPanel/Content/DepthRow/Depth.max_value = depth_limit
 $TacklePanel.map_id = region_id
 $MissionPanel.map_id = region_id

func bind_economy(profile: AnglerProfile, fishing: FishingController, pond: PondEcosystem, commerce: CommerceGateway) -> void:
 $TacklePanel.bind(profile, fishing, pond, commerce)
 $MissionPanel.bind(profile)

func is_tutorial_active() -> bool:
 return $SafeArea/FirstCatch.active

func is_lure_action_held() -> bool:
 return $SafeArea/LureAction.button_pressed

func open_tackle() -> void:
 $TacklePanel.open()

func close_top_panel() -> bool:
 # Preserve the session's existing Back priority: missions, tackle, collection.
 for index in range(_modal_panels.size() - 1, -1, -1):
  if _modal_panels[index].visible:
   _modal_panels[index].call("close")
   return true
 return false

func update_wallet(coins: int) -> void:
 $SafeArea/TackleButton.visible = true
 $SafeArea/TackleButton.text = "กระเป๋า · %d เหรียญ" % coins

func set_boss_notice(message: String) -> void:
 $SafeArea/BossToast.text = message

func set_boss_notice_visible(value: bool) -> void:
 $SafeArea/BossToast.visible = value

func _on_modal_changed() -> void:
 var opened := is_collection_open()
 if opened == _modal_reported:
  return
 _modal_reported = opened
 if opened:
  rod_joystick.reset()
  move_joystick.reset()
  _aim_gesture = false
  settings_panel.hide()
  $SafeArea/FirstCatch.hide()
 collection_visibility_changed.emit(opened)

func bind(fishing: FishingController, pond: PondEcosystem) -> void:
 controller = fishing
 ecology = pond
 last_feedback = controller.feedback
 ready_feedback = controller.feedback
 controller.state_changed.connect(_on_state_changed)
 rod_joystick.drag_started.connect(_on_rod_started)
 ecology.population_changed.connect(_refresh_ecology)
 _on_state_changed()
 $SafeArea/FirstCatch.bind(controller, self)

func _on_state_changed() -> void:
 if controller.state == F.State.READY and last_state != F.State.READY:
  rod_joystick.require_release()
 _aim_gesture = false
 last_state = controller.state
 _refresh_state(last_state)

func rod_direction() -> Vector2:
 return rod_joystick.direction

func is_aiming() -> bool:
 # Ownership also clears a cancelled/focus-lost gesture without casting.
 return _aim_gesture and _can_cast and controller.state == F.State.READY and (rod_joystick.touch_index >= 0 or rod_joystick.mouse_active)

func set_traversal_state(swimming: bool, grounded: bool, controls_enabled: bool) -> void:
 _can_cast = grounded and not swimming
 var ready := controller != null and controller.state in [F.State.READY, F.State.LOST]
 $SafeArea/MovementActions/Jump.disabled = not controls_enabled or not ready
 $SafeArea/MovementActions/LeftActions/Run.disabled = not controls_enabled or swimming or not ready
 $SafeArea/MovementActions/LeftActions/Wave.disabled = not controls_enabled or not _can_cast or not ready
 $SafeArea/MovementActions/Jump.text = "ขึ้นจากน้ำ" if swimming else "กระโดด"
 if controller != null and controller.state == F.State.READY:
  rod_joystick.enabled = _can_cast
  rod_joystick.modulate.a = 1.0 if _can_cast else 0.35

func _on_jump_pressed() -> void:
 jump_requested.emit()

func _on_run_toggled(enabled: bool) -> void:
 run_toggled.emit(enabled)

func _on_wave_pressed() -> void:
 greet_requested.emit()

func set_boat_state(nearby: bool, aboard: bool, driving: bool, can_exit: bool, controls_enabled: bool, can_stand: bool = true) -> void:
 _on_boat = aboard
 $SafeArea/BoatActions.visible = nearby or aboard
 $SafeArea/BoatActions/Action.text = "ตกปลา" if driving else "ขับเรือ"
 $SafeArea/BoatActions/Action.disabled = not controls_enabled or not can_stand
 $SafeArea/BoatActions/Action.tooltip_text = "พื้นที่เหนือเรือไม่พอให้ยืน — ขับออกจากใต้สิ่งกีดขวางก่อน" if not can_stand else "หยุดเรือและยืนตกปลา" if driving else "นั่งขับเรือ"
 $SafeArea/BoatActions/Exit.visible = aboard
 $SafeArea/BoatActions/Exit.disabled = not can_exit or not controls_enabled
 $SafeArea/BoatActions/Exit.tooltip_text = "ลงเรือที่ฝั่งใกล้ที่สุด" if can_exit else "ขับเรือเข้าใกล้ฝั่งก่อนลงเรือ"
 $SafeArea/MovementActions.visible = not aboard and controller.state in [F.State.READY, F.State.LOST]
 $SafeArea/RodJoystick.visible = not driving
 if driving:
  $SafeArea/BaitDock.hide()
 elif controller.state == F.State.READY:
  $SafeArea/BaitDock.show()

func _on_boat_action_pressed() -> void:
 boat_action_requested.emit()

func _on_boat_exit_pressed() -> void:
 boat_exit_requested.emit()

func is_collection_open() -> bool:
 return $CollectionPanel.visible or $TacklePanel.visible or $MissionPanel.visible

func close_collection() -> void:
 $CollectionPanel.close()

func show_catch_result(fish: FishState, save_error: String) -> void:
 $ResultLayer.present(fish, save_error)

func _process(delta: float) -> void:
 if not is_instance_valid(controller):
  return
 var state: int = controller.state
 _refresh_cast_reason(state)
 _refresh_fish_box()
 _refresh_mission_hud(delta)
 $SafeArea/LureAction.visible = controller.using_lure() and state == F.State.WAITING
 if controller.profile != null:
  $SafeArea/TackleButton.visible = state in [F.State.READY, F.State.RESULT, F.State.LOST] and not $SafeArea/FirstCatch.active
  $SafeArea/BaitDock/BaitButton.tooltip_text = controller.profile.equipped("bait").display_name
  if state == F.State.RESULT:
   $ResultLayer/Card/Content/Description.text = controller.feedback
 toast_time = maxf(0.0, toast_time - delta)
 $SafeArea/Toast.visible = toast_time > 0.0
 if controller.feedback != last_feedback:
  last_feedback = controller.feedback
  if state == F.State.READY and last_feedback != ready_feedback:
   _show_toast(last_feedback)
 var titles := ["", "รอปลา", "วัดเบ็ด!", "สู้ปลา", "", "ปลาหลุด", "เหวี่ยง"]
 $SafeArea/Status/Content/State.text = titles[state]
 if state in [F.State.WAITING, F.State.BITE, F.State.FIGHT]:
  rod_joystick.show_reel(controller.rod_input, state == F.State.FIGHT and controller.tension >= controller.red_start and controller.drag_strength < 0.95)
 if state == F.State.FIGHT:
  meter.set_zones(controller.yellow_start, controller.red_start)
  _align_tension_meter()
  meter.value = controller.tension
  $SafeArea/TensionText.text = "%d%%" % int(controller.tension * 100)
  $SafeArea/TensionText.modulate = Color(1, 0.4, 0.35) if controller.tension >= meter.red_start else Color.WHITE
  $SafeArea/LineInfo/Content/Distance.text = "%.1f m" % controller.line_length
  $SafeArea/LineInfo/Content/Reel.visible = true
  $SafeArea/LineInfo/Content/Reel.text = "แรง %.1f / %.0f kgf" % [controller.fight.line_load_kgf, controller.fight.line_strength]
  $SafeArea/LineInfo/Content/Reel.modulate = Color(1, 0.4, 0.35) if controller.fight.line_load_kgf >= controller.fight.line_strength else Color.WHITE
  if controller.tension >= meter.red_start:
   $SafeArea/Status/Content/State.text = "ปลากระชาก! ↑ ผ่อนสาย" if controller.fight.surge_active else "↑ ผ่อนสาย"
  elif controller.tension < meter.yellow_start:
   $SafeArea/Status/Content/State.text = "↓ เก็บสาย • ปลากำลังหนี"
  else:
   $SafeArea/Status/Content/State.text = "ประคองสีเหลือง"
  if controller.fight.line_load_kgf >= controller.fight.line_strength:
   $SafeArea/Status/Content/State.text = "แรงดึงเกินสเปคเอ็น! ↑ ผ่อนสาย"
 elif state == F.State.WAITING or state == F.State.BITE:
  $SafeArea/LineInfo/Content/Reel.visible = false
  $SafeArea/LineInfo/Content/Distance.text = "%.1f m" % controller.line_length

func _refresh_ecology() -> void:
 if $SafeArea/EcologyPanel.visible:
  var counts: Dictionary = ecology.counts()
  var lines := PackedStringArray()
  for index in range(0, ecology.species.size(), 2):
   var name_a: String = ecology.species[index].display_name
   if controller.profile != null and get_node("/root/FishCollection").stats(ecology.species[index].id).count == 0:
    name_a = "???"
   var text: String = "%s %d" % [name_a, counts[ecology.species[index].id]]
   if index + 1 < ecology.species.size():
    var name_b: String = ecology.species[index + 1].display_name
    if controller.profile != null and get_node("/root/FishCollection").stats(ecology.species[index + 1].id).count == 0:
     name_b = "???"
    text += "  •  %s %d" % [name_b, counts[ecology.species[index + 1].id]]
   lines.append(text)
  $SafeArea/EcologyPanel/Content/Counts.text = "\n".join(lines)

func _refresh_cast_reason(state: int) -> void:
 var label: Label = $SafeArea/CastReason
 label.visible = state == F.State.READY and not is_collection_open()
 if label.visible:
  label.text = controller.cast_block_reason()

func _refresh_fish_box() -> void:
 var box: Control = $SafeArea/FishBox
 box.visible = controller.profile != null and not is_collection_open()
 if controller.profile == null:
  return
 var profile := controller.profile
 var weight := profile.box_weight()
 var capacity: float = profile.equipped("box").capacity
 var remaining := maxf(0.0, capacity - weight)
 var fraction := clampf(weight / maxf(capacity, 0.01), 0.0, 1.0)
 var info := box.get_node("Row/Info")
 info.get_node("Count").text = "กล่องปลา · %d ตัว" % profile.data.catches.size()
 info.get_node("Weight").text = "%.1f / %.1f กก." % [weight, capacity]
 info.get_node("Fill").value = fraction * 100.0
 var status_text := "เต็มแล้ว" if remaining < 0.001 else "ใกล้เต็ม" if fraction >= 0.8 else "ยังว่าง" if weight == 0.0 else "มีที่ว่าง"
 info.get_node("State").text = "%s · เหลือ %.1f กก." % [status_text, remaining]
 var color := Color(1, 0.4, 0.35) if remaining < 0.001 else Color(1, 0.82, 0.35) if fraction >= 0.8 else Color(0.65, 1, 0.84)
 info.get_node("State").modulate = color
 info.get_node("Fill").modulate = color

func _align_tension_meter() -> void:
 var guide := rod_joystick.reel_guide_position()
 meter.global_position = guide - Vector2(meter.size.x * 0.5, meter.size.y + tension_reel_gap)
 $SafeArea/TensionText.global_position = Vector2(guide.x + 28.0, meter.global_position.y + meter.size.y * 0.5 - 14.0)

func _refresh_state(state: int) -> void:
 toast_time = 0.0
 $SafeArea/Toast.hide()
 var battle := state == F.State.FIGHT
 $SafeArea/RodInstructions.visible = battle
 $SafeArea/RodInstructions.text = "↑ ผ่อนสาย · ↓ เก็บสาย · ← → คุมคัน"
 var result := state == F.State.RESULT
 $SafeArea/MovementActions.visible = not _on_boat and state in [F.State.READY, F.State.LOST]
 $SafeArea/OrbitButton.disabled = result or state == F.State.CASTING
 if battle and controller.active_fish != null:
  var fish: FishState = controller.active_fish
  controller.fight.update_zones(fish)
  meter.configure_fish(fish.weight, controller.red_start)
  meter.set_zones(controller.yellow_start, controller.red_start)
 rod_joystick.set_battle_mode(state in [F.State.WAITING, F.State.BITE, F.State.FIGHT])
 $SafeArea/CollectionButton.visible = state == F.State.READY
 settings_panel.hide()
 $SafeArea/BaitDock.visible = state == F.State.READY
 $SafeArea/Status.visible = state not in [F.State.READY, F.State.RESULT]
 $SafeArea/EcologyPanel.hide()
 meter.visible = battle
 $SafeArea/TensionText.visible = battle
 $SafeArea/LineInfo.visible = state in [F.State.WAITING, F.State.BITE, F.State.FIGHT]
 rod_joystick.enabled = state in [F.State.READY, F.State.WAITING, F.State.BITE, F.State.FIGHT]
 move_joystick.enabled = not result
 rod_joystick.modulate.a = 1.0 if rod_joystick.enabled else 0.35
 move_joystick.modulate.a = 0.35 if result else 1.0
 $ResultLayer.set_open(result)

func _on_rod_released() -> void:
 var should_cast := _aim_gesture and controller.state == F.State.READY and _can_cast
 _aim_gesture = false
 if should_cast:
  aim_released.emit()

func _on_rod_started() -> void:
 _aim_gesture = controller.state == F.State.READY and _can_cast

func _on_orbit_down() -> void:
 orbit_requested.emit(true)

func _on_orbit_up() -> void:
 orbit_requested.emit(false)

func _on_orbit_dragged(horizontal_motion: float) -> void:
 orbit_dragged.emit(horizontal_motion)

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
 if controller.profile != null:
  _on_tackle_pressed()
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

func _on_tackle_pressed() -> void:
 if controller.profile == null or controller.state not in [F.State.READY, F.State.RESULT, F.State.LOST]:
  return
 rod_joystick.reset()
 move_joystick.reset()
 open_tackle()

func _on_lure_down() -> void:
 controller.lure_input.press()

func _on_lure_up() -> void:
 controller.lure_input.release()

func sync_equipment() -> void:
 # The bag owns bait selection once inventory is enabled. The depth control
 # remains independent and editable during preparation.
 if controller == null or controller.profile == null:
  return
 var select: OptionButton = $SafeArea/BaitPanel/Content/BaitRow/BaitSelect
 var index := [&"worm", &"dough", &"lure"].find(controller.profile.equipped("bait").bait_type)
 select.select(maxi(0, index))
 select.disabled = true
 $SafeArea/BaitDock/BaitButton.icon = BAIT_ICONS[maxi(0, index)]
 $SafeArea/BaitDock/BaitButton.tooltip_text = controller.profile.equipped("bait").display_name

func _on_missions_pressed() -> void:
 if controller == null or controller.profile == null or controller.state != F.State.READY or $SafeArea/FirstCatch.active:
  return
 rod_joystick.reset()
 move_joystick.reset()
 settings_panel.hide()
 $SafeArea/EcologyPanel.hide()
 $MissionPanel.open()

func notify_missions_completed(ids: Array[String]) -> void:
 for id in ids:
  if id not in pending_mission_completions:
   pending_mission_completions.append(id)

func _refresh_mission_hud(delta: float) -> void:
 var ready: bool = controller.profile != null and not $SafeArea/FirstCatch.active and controller.state == F.State.READY and not is_collection_open()
 $SafeArea/MissionButton.visible = ready
 $SafeArea/MissionTracker.hide()
 $SafeArea/MissionToast.visible = ready and mission_toast_time > 0.0
 if not ready:
  return
 var state: Dictionary = controller.profile.data.missions
 var definition := MissionCatalog.find(state.tracked)
 if definition != null:
  var entry := MissionProgress.entry(state, definition)
  $SafeArea/MissionTracker.visible = not entry.claimed
  $SafeArea/MissionTracker/Text.text = "ภารกิจ · %s\n%s%s" % [definition.title, MissionProgress.progress_text(state, definition), " · รับรางวัลได้" if MissionProgress.completed(state, definition) else ""]
 if mission_toast_time <= 0.0 and not pending_mission_completions.is_empty():
  var count := pending_mission_completions.size()
  var first := MissionCatalog.find(pending_mission_completions[0])
  $SafeArea/MissionToast.text = "ภารกิจสำเร็จ · %s%s\nเปิดภารกิจเพื่อรับรางวัล" % [first.title, " และอีก %d ข้อ" % (count - 1) if count > 1 else ""]
  pending_mission_completions.clear()
  mission_toast_time = 5.0
 mission_toast_time = maxf(0.0, mission_toast_time - delta)
 $SafeArea/MissionToast.visible = mission_toast_time > 0.0
