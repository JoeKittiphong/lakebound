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
signal boat_use_requested
signal boat_pack_requested
signal boat_place_requested
signal boat_place_cancelled
signal fishing_perspective_changed(first_person: bool)
signal configuration_changed(bait: StringName, depth: float)

const F = preload("res://features/fishing/fishing_controller.gd")
const STATE_TITLES = ["", "รอปลา", "วัดเบ็ด!", "สู้ปลา", "", "ปลาหลุด", "เหวี่ยง"]
const BAIT_IDS = [&"worm", &"dough", &"lure"]
const BAIT_ICONS = [preload("res://assets/ui/shop/equipment_atlas/worm.tres"), preload("res://assets/ui/shop/equipment_atlas/dough.tres"), preload("res://assets/ui/shop/equipment_atlas/minnow.tres")]
@onready var move_joystick: Control = $SafeArea/MoveJoystick
@onready var rod_joystick: RodControl = $SafeArea/RodJoystick
@onready var settings_panel: Control = $SafeArea/BaitPanel
@onready var meter: Control = $SafeArea/TensionMeter
@onready var _state_text: Label = $SafeArea/Status/Content/State
@onready var _line_distance: Label = $SafeArea/LineInfo/Content/Distance
@onready var _line_load: Label = $SafeArea/LineInfo/Content/Reel
@onready var _tension_text: Label = $SafeArea/TensionText
@onready var _modal_panels: Array[Control] = [$CollectionPanel, $TacklePanel, $MissionPanel, $MapPanel, $FishStoragePanel, $GameSettingsPanel, $SocialPanel]
var _modal_reported := false
var competition_mode := false
var controller: FishingController
var ecology: PondEcosystem
var last_state: int = -1
var _aim_gesture := false
var _can_cast := true
var _on_boat := false
var _boat_nearby := false
var _boat_driving := false
var toast_time := 0.0
var last_feedback := ""
var ready_feedback := ""
@onready var _mission_hud := MissionHUD.new($SafeArea/TopBar/Actions/MissionButton, $SafeArea/MissionTracker, $SafeArea/MissionToast)
@export var tension_reel_gap: float = 24.0

func _exit_tree() -> void:
	_mission_hud.bind(null)

func _ready() -> void:
	# HUD owns its panels. Session receives only aggregate modal transitions so
	# closing one panel cannot unpause another panel that is still open.
	for panel in _modal_panels:
		panel.connect("opened", _on_modal_changed)
		panel.connect("closed", _on_modal_changed)
	$GameSettingsPanel.menu_requested.connect(_on_back_pressed)
	$GameSettingsPanel.help_requested.connect(_open_settings_help)
	$SafeArea/Minimap.pressed.connect(open_map)
	$MapPanel.target_changed.connect($SafeArea/Minimap.set_target)
	$MapPanel.spots_changed.connect($SafeArea/Minimap.set_spots)
	$CollectionPanel.history_requested.connect(_open_species_map)
	$SafeArea/TopBar/Actions/FishBox.pressed.connect(open_fish_storage)
	$TacklePanel/DepthSettings/Slider.value_changed.connect(func(value: float):
		$SafeArea/BaitPanel/Content/DepthRow/Depth.value=value
		$TacklePanel/DepthSettings/Label.text="ความลึก %.1f ม."%value)

func bind_map(profile: AnglerProfile, player: AnglerPlayer, _definition: PondDefinition) -> void:
	$SafeArea/Minimap.visible = profile != null
	$SafeArea/RankingButton.bind(get_node_or_null("/root/RankingOnline") if profile != null else null, str(controller.map_id))
	$SafeArea/Minimap.bind(player, controller.map_id, ecology)
	$MapPanel.bind(profile, player, controller.map_id, ecology)
	$CollectionPanel.map_history_enabled = profile != null

func open_map() -> void:
	if controller == null or controller.state not in [F.State.READY, F.State.WAITING, F.State.LOST]:
		return
	$MapPanel.open()

func open_map_ranking() -> void:
	if competition_mode:return
	if controller == null or controller.profile == null or controller.state not in [F.State.READY, F.State.WAITING, F.State.LOST]:
		return
	$SocialPanel.open_for_map(str(controller.map_id))

func _open_species_map(species_id: String) -> void:
	if controller == null or controller.state != F.State.READY:
		return
	# Open before closing the collection to keep one continuous modal pause.
	$MapPanel.open(species_id, $CollectionPanel.selected_map)
	$CollectionPanel.close()

func configure_session(region_id: String, depth_limit: float) -> void:
	$SafeArea/BaitPanel/Content/DepthRow/Depth.max_value = depth_limit
	$TacklePanel/DepthSettings/Slider.max_value = depth_limit
	$TacklePanel.map_id = region_id
	$MissionPanel.map_id = region_id
	$FishStoragePanel.map_id = region_id

func bind_economy(profile: AnglerProfile, fishing: FishingController, pond: PondEcosystem, commerce: CommerceGateway) -> void:
	$TacklePanel.bind(profile, fishing, pond, commerce)
	$SafeArea/BagDock.bind(profile, fishing)
	$SafeArea/BagDock.category_requested.connect($TacklePanel.open_category)
	$SafeArea/BagDock.boat_requested.connect(func():boat_use_requested.emit())
	$SafeArea/BagDock.fish_requested.connect(open_fish_storage)
	$MissionPanel.bind(profile)
	$FishStoragePanel.bind(profile, pond)

func open_fish_storage() -> void:
	if controller == null or controller.profile == null or controller.state not in [F.State.READY, F.State.LOST]:
		return
	$FishStoragePanel.open()

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
			_modal_panels[index].call("close_top_layer" if _modal_panels[index].has_method("close_top_layer") else "close")
			return true
	return false

func update_wallet(coins: int, diamonds: int = 0) -> void:
	$SafeArea/TopBar/Actions/Wallet/Coins/Amount.text = _compact_currency(coins)
	$SafeArea/TopBar/Actions/Wallet/Gems/Amount.text = _compact_currency(diamonds)
	$SafeArea/TopBar/Actions/Wallet/Coins/Amount.tooltip_text = str(coins)
	$SafeArea/TopBar/Actions/Wallet/Gems/Amount.tooltip_text = str(diamonds)

func _compact_currency(value: int) -> String:
	if value >= 1000000:
		return ("%.1f" % (value / 1000000.0)).trim_suffix(".0") + "M"
	if value >= 10000:
		return ("%.1f" % (value / 1000.0)).trim_suffix(".0") + "K"
	return str(value)

func set_boss_notice(message: String) -> void:
	$SafeArea/BossToast.text = message

func set_boss_notice_visible(value: bool) -> void:
	$SafeArea/BossToast.visible = value and not is_tutorial_active()

func _on_modal_changed() -> void:
	var opened := is_collection_open()
	if opened == _modal_reported:
		return
	_modal_reported = opened
	$SafeArea.visible = not opened
	if opened:
		rod_joystick.reset()
		move_joystick.reset()
		controller.lure_gestures.reset()
		controller.lure_rhythm.reset()
		controller.ecosystem.invalidate_lure_action()
		controller.lure_input.reset()
		controller.lure_holding = false
		_aim_gesture = false
		settings_panel.hide()
		$SafeArea/EcologyPanel.hide()
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
	if controller.state != last_state:
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
	var traversal_ready := controller != null and controller.state in [F.State.READY, F.State.LOST]
	$SafeArea/MovementActions/Jump.disabled = not controls_enabled or not traversal_ready
	$SafeArea/MovementActions/LeftActions/Run.disabled = not controls_enabled or swimming or not traversal_ready
	$SafeArea/MovementActions/LeftActions/Wave.disabled = not controls_enabled or not _can_cast or not traversal_ready
	$SafeArea/MovementActions/Jump.text = "ขึ้นจากน้ำ" if swimming else "กระโดด"
	if controller != null and controller.state == F.State.READY:
		rod_joystick.enabled = _can_cast
		rod_joystick.modulate.a = 1.0 if _can_cast else 0.35

func _on_jump_pressed() -> void:
	jump_requested.emit()

func _on_run_toggled(enabled: bool) -> void:
	run_toggled.emit(enabled)

func set_auto_run(active: bool) -> void:
	var button: Button = $SafeArea/MovementActions/LeftActions/Run
	button.set_pressed_no_signal(active)
	button.text = "หยุดวิ่ง" if active else "วิ่ง"

func _on_wave_pressed() -> void:
	greet_requested.emit()

func set_boat_state(nearby: bool, aboard: bool, driving: bool, can_exit: bool, controls_enabled: bool, can_stand: bool = true) -> void:
	_on_boat = aboard
	_boat_nearby = nearby
	_boat_driving = driving
	$SafeArea/BoatActions.visible = nearby or aboard
	$SafeArea/BoatActions/Action.text = "ตกปลา / เดิน" if driving else "ขับเรือ"
	$SafeArea/BoatActions/Action.disabled = not controls_enabled or not can_stand
	$SafeArea/BoatActions/Action.tooltip_text = "พื้นที่เหนือเรือไม่พอให้ยืน — ขับออกจากใต้สิ่งกีดขวางก่อน" if not can_stand else "หยุดเรือและยืนตกปลา" if driving else "นั่งขับเรือ"
	$SafeArea/BoatActions/Exit.visible = aboard
	$SafeArea/BoatActions/Exit.disabled = not can_exit or not controls_enabled
	$SafeArea/BoatActions/Exit.tooltip_text = "ลงฝั่งใกล้เรือ หรือลงน้ำเพื่อว่ายน้ำ" if can_exit else "ยังไม่มีพื้นที่ว่างให้ลงจากเรือ"
	$SafeArea/BoatActions/Pack.disabled = not controls_enabled or driving
	$SafeArea/BoatActions/Pack.tooltip_text = "เลิกขับก่อนเก็บเรือ" if driving else "เก็บเรือกลับช่องอุปกรณ์"
	$SafeArea/MovementActions/Jump.visible = not nearby and not aboard
	$SafeArea/MovementActions.visible = not aboard and controller.state in [F.State.READY, F.State.LOST]
	$SafeArea/RodJoystick.visible = not driving
	if driving:
		$SafeArea/BaitDock.hide()
	elif controller.state == F.State.READY:
		$SafeArea/BaitDock.show()

	_apply_fishing_visibility(controller.state)

func _on_boat_action_pressed() -> void:
	boat_action_requested.emit()

func _on_boat_exit_pressed() -> void:
	boat_exit_requested.emit()

func _on_boat_pack_pressed() -> void:
	boat_pack_requested.emit()

func _on_boat_place_pressed() -> void:
	boat_place_requested.emit()

func _on_boat_place_cancelled() -> void:
	boat_place_cancelled.emit()

func is_collection_open() -> bool:
	for panel in _modal_panels:
		if panel.visible:
			return true
	return false

func close_collection() -> void:
	$CollectionPanel.close()

func show_catch_result(fish: FishState, save_error: String) -> void:
	$ResultLayer.present(fish, save_error)

func _process(delta: float) -> void:
	if not is_instance_valid(controller):
		return
	var state: int = controller.state
	$SafeArea/RankingButton.disabled = controller.profile == null or state not in [F.State.READY, F.State.WAITING, F.State.LOST]
	$SafeArea/Minimap.disabled = state not in [F.State.READY, F.State.WAITING, F.State.LOST]
	$SafeArea/Minimap.visible = controller.profile != null and state in [F.State.READY, F.State.WAITING, F.State.LOST] and not is_collection_open()
	$SafeArea/RankingButton.visible = not competition_mode and $SafeArea/Minimap.visible
	_refresh_cast_reason(state)
	_refresh_fish_box()
	_mission_hud.refresh(controller.profile, not competition_mode and controller.profile != null and not is_tutorial_active() and state == F.State.READY and not is_collection_open(), delta)
	$SafeArea/LureAction.visible = false
	var lure_mode: bool = controller.using_lure() and state == F.State.WAITING
	var rhythm_panel: Control = $SafeArea/Status/Content/LureRhythm
	rhythm_panel.visible = lure_mode
	_state_text.visible = not lure_mode
	$SafeArea/LureHint.hide()
	if lure_mode:
		var rhythm = controller.lure_rhythm
		rhythm_panel.get_node("Sequence").text = rhythm.sequence_text()
		rhythm_panel.get_node("Sequence").modulate = Color(0.55, 1, 0.78) if rhythm.hit else Color(1, 0.85, 0.35)
		rhythm_panel.get_node("Feedback").text = rhythm.feedback.replace("เต็มหลอด", "ครบสูตร").replace("และหลอด", "")
	# The PanelContainer grows for the authored rhythm content, then returns to
	# its original compact announcement bounds for bites and fights.
	var announcement_size: Vector2 = $SafeArea/Status.get_combined_minimum_size().max(Vector2(240, 52))
	$SafeArea/Status.offset_left = -announcement_size.x * 0.5
	$SafeArea/Status.offset_right = announcement_size.x * 0.5
	$SafeArea/Status.offset_bottom = $SafeArea/Status.offset_top + announcement_size.y
	if state == F.State.FIGHT:
		var lateral: float = controller.fight.lateral_direction
		$SafeArea/LureHint.visible = true
		$SafeArea/LureHint.text = "ปลาหนี →  หักคัน ←" if lateral > 0.2 else ("ปลาหนี ←  หักคัน →" if lateral < -0.2 else "ปลาประคองตัว • อ่านแรงตึง")
	if controller.profile != null:
		$SafeArea/TopBar/Actions/TackleButton.visible = false
		$SafeArea/BaitDock/BaitButton.tooltip_text = controller.profile.equipment_name("bait")
		$SafeArea/BaitDock/BaitButton.icon = (controller.profile.equipped("bait").shop_icon if controller.profile.equipped("bait") != null else null)
		if state == F.State.RESULT:
			$ResultLayer/Card/Content/Description.text = controller.feedback
	toast_time = maxf(0.0, toast_time - delta)
	$SafeArea/Toast.visible = toast_time > 0.0
	if controller.feedback != last_feedback:
		last_feedback = controller.feedback
		if state == F.State.READY and last_feedback != ready_feedback:
			_show_toast(last_feedback)
	_state_text.text = STATE_TITLES[state]
	if state == F.State.FIGHT:
		meter.set_zones(controller.yellow_start, controller.red_start)
		meter.value = controller.tension
		_tension_text.text = "%d%%" % int(controller.tension * 100)
		_tension_text.modulate = Color(1, 0.4, 0.35) if controller.tension >= meter.red_start else Color.WHITE
		_line_distance.text = "%.1f m" % controller.line_length
		_line_load.visible = true
		_line_load.text = "แรง %.1f / %.0f kgf" % [controller.fight.line_load_kgf, controller.fight.line_strength]
		_line_load.modulate = Color(1, 0.4, 0.35) if controller.fight.line_load_kgf >= controller.fight.line_strength else Color.WHITE
		if controller.tension >= meter.red_start:
			_state_text.text = "ปลากระชาก! ↑ ผ่อนสาย" if controller.fight.surge_active else "↑ ผ่อนสาย"
		elif controller.tension < meter.yellow_start:
			_state_text.text = "↓ เก็บสาย • ปลากำลังหนี"
		else:
			_state_text.text = "ประคองสีเหลือง"
		if controller.fight.line_load_kgf >= controller.fight.line_strength:
			_state_text.text = "แรงดึงเกินสเปคเอ็น! ↑ ผ่อนสาย"
	elif state == F.State.WAITING or state == F.State.BITE:
		_line_load.visible = false
		_line_distance.text = "%.1f m" % controller.line_length

	_refresh_fish_health(state)
	_align_tension_meter()
	_apply_fishing_visibility(state)

func _refresh_ecology(force: bool = false) -> void:
	if force or $SafeArea/EcologyPanel.visible:
		var counts: Dictionary = ecology.counts()
		var lines := PackedStringArray()
		for index in range(0, ecology.species.size(), 2):
			var text := _ecology_entry(index, counts)
			if index + 1 < ecology.species.size():
				text += "  •  " + _ecology_entry(index + 1, counts)
			lines.append(text)
		$SafeArea/EcologyPanel/Content/Counts.text = "\n".join(lines)

func _ecology_entry(index: int, counts: Dictionary) -> String:
	var species = ecology.species[index]
	var discovered: bool = controller.profile == null or get_node("/root/FishCollection").stats(species.id).count > 0
	return "%s %d" % [species.display_name if discovered else "???", counts[species.id]]

func _refresh_cast_reason(state: int) -> void:
	var label: Label = $SafeArea/CastReason
	label.visible = state == F.State.READY and not is_collection_open()
	if label.visible:
		label.text = controller.cast_block_reason()

func _refresh_fish_box() -> void:
	var box: FishBoxView = $SafeArea/TopBar/Actions/FishBox
	box.visible = controller.profile != null and controller.state in [F.State.READY, F.State.WAITING, F.State.LOST] and not is_collection_open()
	box.get_node("Open").disabled = controller.state not in [F.State.READY, F.State.LOST]
	box.bind(controller.profile)
	box.refresh_if_needed()

func _align_tension_meter() -> void:
	var rod_rect := rod_joystick.get_global_rect()
	meter.global_position = Vector2(rod_rect.position.x - meter.size.x - tension_reel_gap, rod_rect.end.y - meter.size.y - 18.0)
	_tension_text.global_position = meter.global_position + Vector2((meter.size.x - _tension_text.size.x) * 0.5, meter.size.y + 4.0)

	var info: Control = $SafeArea/LineInfo
	info.global_position = Vector2(rod_rect.get_center().x - info.size.x * 0.5, rod_rect.position.y - info.size.y - 16.0)
	var boat_actions: Control = $SafeArea/BoatActions
	boat_actions.global_position = Vector2(rod_rect.get_center().x - boat_actions.size.x * .5,rod_rect.position.y - boat_actions.size.y - 16.0)

func _refresh_state(state: int) -> void:
	if state != F.State.READY:
		$SafeArea/BossToast.hide()
	toast_time = 0.0
	$SafeArea/Toast.hide()
	$SafeArea/TopBar/Actions/SettingsButton.disabled = state not in [F.State.READY,F.State.WAITING,F.State.LOST]
	$SafeArea/TopBar/Actions/TackleButton.disabled = state not in [F.State.READY,F.State.RESULT,F.State.LOST]
	var battle := state == F.State.FIGHT
	$SafeArea/RodInstructions.visible = state in [F.State.WAITING, F.State.BITE, F.State.FIGHT]
	$SafeArea/RodInstructions.text = "↑ กระตุก · ↓ กรอ · ← → สะบัด" if state == F.State.WAITING and controller.using_lure() else ("↓ วัดเบ็ด" if state == F.State.BITE else "↑ ผ่อนสาย · ↓ เก็บสาย · ← → คุมคัน")
	var result := state == F.State.RESULT
	$SafeArea/MovementActions.visible = not _on_boat and state in [F.State.READY, F.State.LOST]
	$SafeArea/OrbitButton.disabled = result or state == F.State.CASTING
	if battle and controller.active_fish != null:
		var fish: FishState = controller.active_fish
		controller.fight.update_zones(fish)
		meter.configure_fish(fish.weight, controller.red_start)
		meter.set_zones(controller.yellow_start, controller.red_start)
	rod_joystick.set_battle_mode(state in [F.State.WAITING, F.State.BITE, F.State.FIGHT])
	$SafeArea/TopBar/Actions/CollectionButton.visible = state == F.State.READY
	settings_panel.hide()
	$SafeArea/BaitDock.visible = false # Equipment selection lives in BagDock.
	$SafeArea/BagDock.visible = state in [F.State.READY,F.State.LOST]
	$SafeArea/Status.visible = state not in [F.State.READY, F.State.RESULT]
	$SafeArea/EcologyPanel.hide()
	meter.visible = battle
	_tension_text.visible = battle
	$SafeArea/LineInfo.visible = state in [F.State.WAITING, F.State.BITE, F.State.FIGHT]
	rod_joystick.enabled = state in [F.State.READY, F.State.WAITING, F.State.BITE, F.State.FIGHT]
	move_joystick.enabled = not result
	rod_joystick.modulate.a = 1.0 if rod_joystick.enabled else 0.35
	move_joystick.modulate.a = 0.35 if result else 1.0
	$ResultLayer.set_open(result)

	_apply_fishing_visibility(state)

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

func open_settings() -> void:
	if controller == null or controller.state not in [F.State.READY,F.State.WAITING,F.State.LOST]: return
	$GameSettingsPanel.open()

func _open_settings_help() -> void:
	_refresh_ecology(true)
	$GameSettingsPanel.show_help($SafeArea/EcologyPanel/Content/Guide.text + "\n\n" + $SafeArea/EcologyPanel/Content/Counts.text)

func _on_ecology_pressed() -> void:
	open_settings()
	if $GameSettingsPanel.visible: _open_settings_help()

func _on_collection_pressed() -> void:
	if controller.state != F.State.READY:
		return
	$CollectionPanel.open()

func _on_config_changed(_value = 0) -> void:
	var depth: float = $SafeArea/BaitPanel/Content/DepthRow/Depth.value
	$SafeArea/BaitPanel/Content/DepthRow/Value.text = "%.1f ม." % depth
	$SafeArea/BaitDock/DepthButton.text = "%.1f" % depth
	var selected: int = $SafeArea/BaitPanel/Content/BaitRow/BaitSelect.selected
	$SafeArea/BaitDock/BaitButton.icon = BAIT_ICONS[selected]
	$SafeArea/BaitDock/BaitButton.tooltip_text = $SafeArea/BaitPanel/Content/BaitRow/BaitSelect.get_item_text(selected)
	configuration_changed.emit(BAIT_IDS[$SafeArea/BaitPanel/Content/BaitRow/BaitSelect.selected], depth)

func _on_bait_pressed() -> void:
	if controller.state != F.State.READY:
		return
	if controller.profile != null:
		$TacklePanel.open_category(1)
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
	var index := BAIT_IDS.find(controller.profile.equipped("bait").bait_type) if controller.profile.equipped("bait") != null else -1
	select.select(maxi(0, index))
	select.disabled = true
	$SafeArea/BaitDock/BaitButton.icon = (controller.profile.equipped("bait").shop_icon if controller.profile.equipped("bait") != null else null)
	$SafeArea/BaitDock/BaitButton.tooltip_text = controller.profile.equipment_name("bait")

func _on_missions_pressed() -> void:
	if competition_mode:return
	if controller == null or controller.profile == null or controller.state != F.State.READY or $SafeArea/FirstCatch.active:
		return
	$MissionPanel.open()

func notify_missions_completed(ids: Array[String]) -> void:
	_mission_hud.notify_completed(ids)

func _apply_fishing_visibility(state: int) -> void:
	var fishing_mode := state in [F.State.CASTING, F.State.WAITING, F.State.BITE, F.State.FIGHT]
	$SafeArea/RankingButton.visible = not competition_mode and not fishing_mode and state in [F.State.READY, F.State.LOST] and controller.profile != null
	$SafeArea/PerspectiveButton.visible = true
	$SafeArea/BaitDock.visible = false # Equipment selection lives in BagDock.
	$SafeArea/BagDock.visible = state in [F.State.READY,F.State.LOST] and not _boat_driving
	$SafeArea/OrbitButton.visible = false
	$SafeArea/BoatActions.visible = not fishing_mode and (_boat_nearby or _on_boat)
	$SafeArea/TopBar.visible = not fishing_mode
	$SafeArea/MovementActions.visible = not fishing_mode and not _on_boat and state in [F.State.READY, F.State.LOST]
	if fishing_mode:
		$SafeArea/RankingButton.hide()
		$SafeArea/Minimap.hide()
		$SafeArea/MissionTracker.hide()
		$SafeArea/MissionToast.hide()
		$SafeArea/BossToast.hide()
		$SafeArea/RodInstructions.hide()
		settings_panel.hide()

func _on_perspective_toggled(first_person: bool) -> void:
	$SafeArea/PerspectiveButton.text = "1st" if first_person else "3rd"
	fishing_perspective_changed.emit(first_person)

func _refresh_fish_health(state: int) -> void:
	var active := state == F.State.FIGHT and controller.active_fish != null
	$SafeArea/FishHealth.visible = active
	meter.exhausted = active and controller.fight.exhausted
	if not active: return
	$SafeArea/FishHealth.update_health(controller.active_fish.weight, controller.fight.health, controller.fight.maximum_health)
	$SafeArea/Status.hide()
	$SafeArea/LureHint.show()
	if controller.fight.exhausted:
		$SafeArea/LureHint.text = "↓ กรอปลาเข้าฝั่ง • ปลาหมดแรงแล้ว"
		_tension_text.modulate = Color(1, 0.85, 0.35)
		_line_load.text = "ปลาหมดแรง"
	elif controller.fight.line_load_kgf >= controller.fight.line_strength:
		$SafeArea/LureHint.text = "แรงเกินสเปคเอ็น! ↑ ผ่อนสายก่อนสายขาด"
	else:
		$SafeArea/LureHint.text = "ประคองเหลือง/แดงเพื่อลดเลือด • แดงเสี่ยงสายขาด"

func set_competition_mode(enabled: bool) -> void:
	competition_mode = enabled
	if enabled:
		$SafeArea/RankingButton.hide()
		$SafeArea/TopBar/Actions/MissionButton.hide()
		$SafeArea/MissionTracker.hide()
		$SafeArea/MissionToast.hide()
