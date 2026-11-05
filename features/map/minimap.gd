extends Button
signal scan_performed(count: int)
@export_range(0.05,0.5) var update_interval := 0.1
@export_range(10.0,200.0) var radius_m := 100.0
@export_range(1.0,15.0) var scan_duration := 6.0
@export_range(0.2,2.0) var pulse_duration := 0.75
var player: AnglerPlayer
var current_map := "river"
var target: Dictionary = {}
var ecosystem: PondEcosystem
var _elapsed := 0.0
var _scan_remaining := 0.0
var _scan_age := 0.0
var _detected: Array[RefCounted] = []
var _live_ids: Dictionary = {}
@onready var view: LocalMinimapView = $Content/View

func _ready() -> void:
	view.radius_m = radius_m
	$ScanButton.disabled = true
	for tier in 5:
		var label: Label = $ScanLegend/Content.get_child(tier + 1)
		label.text = view.scan_palette.legend_for(tier)
		label.add_theme_color_override("font_color",view.scan_palette.color_for(tier))

func bind(value: AnglerPlayer, map: String, source: PondEcosystem = null) -> void:
	_disconnect_ecosystem()
	player = value
	current_map = map
	ecosystem = source
	$HelpButton.set_pressed_no_signal(false)
	$ScanLegend.hide()
	_clear_scan()
	view.radius_m = radius_m
	view.configure(FishingMapDefinition.for_region(map))
	if is_instance_valid(ecosystem):
		ecosystem.population_changed.connect(_population_changed)
	_population_changed()
	_sync_player()
	$ScanButton.disabled = disabled or not is_instance_valid(player) or not is_instance_valid(ecosystem)

func _exit_tree() -> void:
	_disconnect_ecosystem()

func _disconnect_ecosystem() -> void:
	if is_instance_valid(ecosystem) and ecosystem.population_changed.is_connected(_population_changed):
		ecosystem.population_changed.disconnect(_population_changed)

func _population_changed() -> void:
	_live_ids.clear()
	if is_instance_valid(ecosystem):
		for fish in ecosystem.fish:
			if is_instance_valid(fish): _live_ids[fish.get_instance_id()] = true
	_sync_hits()

func set_spots(spots: Array) -> void:
	view.set_history([],spots)

func set_target(value: Dictionary) -> void:
	target = value
	view.target = value
	_elapsed = update_interval

func _has_point(point: Vector2) -> bool:
	# A transparent corner must not behave like an invisible rectangular map button.
	return point.distance_squared_to(Vector2(98,104)) <= 92.0*92.0 or Rect2(140,142,48,48).has_point(point) or $HelpButton.get_rect().has_point(point)

func _on_help_toggled(opened: bool) -> void:
	$ScanLegend.visible = opened

func _sync_player() -> void:
	if not is_instance_valid(player): return
	view.radius_m = radius_m
	view.set_player(Vector2(player.global_position.x,player.global_position.z),player.visual.global_rotation.y)
	var navigation_hint := "เปิดแผนที่และประวัติจุดตกปลา"
	if not target.is_empty():
		var difference: Vector2 = target.position - view.player_position
		navigation_hint += " · ถึงจุดหมายแล้ว" if difference.length() <= 3 else " · จุดหมาย %.0f ม." % difference.length()
	tooltip_text = navigation_hint

func scan_fish() -> void:
	if disabled or not is_visible_in_tree() or not is_instance_valid(player) or not is_instance_valid(ecosystem): return
	_sync_player()
	_population_changed()
	_detected.clear()
	for fish in ecosystem.fish:
		if is_instance_valid(fish) and fish.position.is_finite() and view.in_range(Vector2(fish.position.x,fish.position.z)):
			_detected.append(fish)
	_scan_remaining = scan_duration
	_scan_age = 0.0
	$ScanFeedback.text = "พบปลา" if not _detected.is_empty() else "ไม่พบปลา"
	$ScanFeedback.show()
	$ScanButton.tooltip_text = "สแกนปลาอีกครั้ง" if not _detected.is_empty() else "ไม่พบปลาในระยะสแกน · กดเพื่อลองอีกครั้ง"
	_sync_hits()
	view.pulse_progress = 0.0
	view.queue_redraw()
	scan_performed.emit(_detected.size())

func _clear_scan() -> void:
	_scan_remaining = 0.0
	_scan_age = 0.0
	_detected.clear()
	view.fish_positions = PackedVector2Array()
	view.fish_tiers = PackedInt32Array()
	view.pulse_progress = -1.0
	$ScanFeedback.hide()
	view.queue_redraw()

func _sync_hits() -> void:
	var positions := PackedVector2Array()
	var tiers := PackedInt32Array()
	if _scan_remaining > 0:
		var boss: RefCounted = ecosystem.boss() if is_instance_valid(ecosystem) else null
		for fish in _detected:
			if not is_instance_valid(fish) or not _live_ids.has(fish.get_instance_id()) or not fish.position.is_finite(): continue
			var point := Vector2(fish.position.x,fish.position.z)
			if view.in_range(point):
				positions.append(point)
				tiers.append(view.scan_palette.classify(fish.weight,fish == boss))
	view.fish_positions = positions
	view.fish_tiers = tiers
	view.marker_alpha = clampf(_scan_remaining,0.0,1.0)
	view.queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	$ScanButton.disabled = disabled or not is_instance_valid(player) or not is_instance_valid(ecosystem)
	if _scan_remaining > 0:
		_scan_remaining = maxf(0.0,_scan_remaining-delta)
		_scan_age += delta
		view.pulse_progress = _scan_age / pulse_duration if _scan_age < pulse_duration else -1.0
		if _scan_age >= 1.5: $ScanFeedback.hide()
		if _scan_remaining <= 0: _clear_scan()
		elif _scan_age < pulse_duration: view.queue_redraw()
	_elapsed += delta
	if _elapsed < update_interval: return
	_elapsed = 0.0
	_sync_player()
	_sync_hits()
