extends Control
const Tile = preload("res://features/collection/collection_fish_tile.tscn")
const Progress = preload("res://features/collection/collection_progress.gd")
const Silhouette = preload("res://features/collection/fish_silhouette.tres")
const PER_PAGE := 15
## Empty list follows RegionCatalog; otherwise list map IDs here ("" means All).
@export var ribbon_maps := PackedStringArray()
signal opened
signal closed
signal history_requested(species_id: String)
var selected_map := ""
var selected_species := ""
var profile: AnglerProfile
var map_history_enabled := false
var page := 0
var page_count := 1
var filtered_species: Array = []
var phase := "hidden"
var _map_stats: Dictionary = {}
var _next_page := 0
var _pending_close := false
var _finger := -2
var _start := Vector2.ZERO
var _travel := 0.0
var _ink := 1.0
var _ink_tween: Tween
var _ribbon_ids: Array[String] = []
@onready var collection: Node = get_node("/root/FishCollection")
@onready var rows: GridContainer = $Card/Content/Scroll/Rows
@onready var details: Control = $Card/Content/DetailsFrame
@onready var animation: AnimationPlayer = $Motion/Viewport/Stage/Book.find_child("AnimationPlayer", true, false)
@onready var viewport: SubViewport = $Motion/Viewport
@onready var model_mesh: MeshInstance3D = $Motion/Viewport/Stage/Book.find_child("CollectionBook_Mesh", true, false)

func _ready() -> void:
	profile = get_node_or_null("/root/AnglerSave")
	_configure_ribbons()
	for i in $Card/Content/MapTabs.get_child_count():
		$Card/Content/MapTabs.get_child(i).pressed.connect(select_map.bind(i))
	collection.changed.connect(_refresh_if_open)
	if profile != null: profile.changed.connect(_refresh_if_open)
	animation.animation_finished.connect(_on_motion_finished)
	$Card/Content/Scroll.resized.connect(_fit_grid)
	$Motion.resized.connect(_queue_book_fit)
	_queue_book_fit()

func _configure_ribbons() -> void:
	if ribbon_maps.is_empty():
		_ribbon_ids.append("")
		for region in RegionCatalog.MAPS: _ribbon_ids.append(String(region.id))
	else:
		for map_id in ribbon_maps:
			var valid := map_id.is_empty()
			for region in RegionCatalog.MAPS:
				if region.id == map_id: valid = true
			if valid:
				if map_id not in _ribbon_ids: _ribbon_ids.append(map_id)
	if _ribbon_ids.is_empty(): _ribbon_ids.append("")
	var tabs := $Card/Content/MapTabs
	var template: Button = tabs.get_child(0)
	while tabs.get_child_count() < _ribbon_ids.size():
		var button := template.duplicate() as Button
		button.name = "Tab%d" % tabs.get_child_count()
		tabs.add_child(button)
	while tabs.get_child_count() > _ribbon_ids.size():
		tabs.get_child(tabs.get_child_count()-1).free()
	if selected_map not in _ribbon_ids: selected_map = _ribbon_ids[0]

func _queue_book_fit() -> void: _fit_book_ui.call_deferred()

func _fit_book_ui() -> void:
	if not is_node_ready() or $Motion.size.x < 1.0: return
	var camera: Camera3D = $Motion/Viewport/Stage/Camera
	var aspect: float = $Motion.size.x / maxf(1.0,$Motion.size.y)
	camera.size = maxf(3.2,4.8/aspect)
	var book: Node3D = $Motion/Viewport/Stage/Book
	var top := camera.unproject_position(book.global_transform * Vector3(-1.40,0.23,-0.96))
	var bottom := camera.unproject_position(book.global_transform * Vector3(1.40,0.23,0.94))
	var scale_to_ui: Vector2 = $Motion.size / Vector2(viewport.size)
	top = $Motion.position + top * scale_to_ui
	bottom = $Motion.position + bottom * scale_to_ui
	var content: Control = $Card/Content
	content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	content.position = top - $Card.position
	content.size = bottom - top
	_fit_grid()
	if visible and phase == "ready": viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _set_ink(value: float) -> void:
	_ink = value
	for path in ["Header/Title","Header/Summary","Filters","Scroll","PageHint","DetailsFrame","SaveStatus"]:
		$Card/Content.get_node(path).modulate.a = value

func _fade_ink(value: float, duration: float) -> void:
	if _ink_tween != null: _ink_tween.kill()
	if duration <= 0: _set_ink(value); return
	_ink_tween = create_tween()
	_ink_tween.tween_method(_set_ink,_ink,value,duration)

func _exit_tree() -> void:
	if is_instance_valid(profile) and profile.changed.is_connected(_refresh_if_open):
		profile.changed.disconnect(_refresh_if_open)

func _fit_grid() -> void:
	if not is_node_ready(): return
	var area: Vector2 = $Card/Content/Scroll.size
	var tile_size := Vector2(maxf(1.0, floorf((area.x - 28.0) / 5.0)), maxf(50.0, floorf((area.y - 16.0) / 3.0)))
	for tile in rows.get_children(): tile.custom_minimum_size = tile_size

func open() -> void:
	if visible and phase != "hidden": return
	page = 0
	_pending_close = false
	_finger = -2
	_refresh()
	show()
	opened.emit()
	_motion("opening", "OpenBook", false)

func _motion(next_phase: String, clip: StringName, reverse: bool) -> void:
	phase = next_phase
	_finger = -2
	_enable_navigation(false)
	if next_phase == "turning":
		$Card.show()
		_fade_ink(0.0,0.10)
	else:
		$Card.hide()
		_fade_ink(0.0,0.0)
	model_mesh.show()
	$Motion.show()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if reverse: animation.play_backwards(clip)
	else: animation.play(clip)

func _on_motion_finished(_clip: StringName) -> void:
	# Modal listeners may remove the scene. Finish outside AnimationMixer's callback.
	_finish_motion.call_deferred()

func _finish_motion() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if phase == "closing":
		phase = "hidden"
		_pending_close = false
		hide()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		closed.emit()
		return
	if phase == "turning":
		page = _next_page
		_refresh()
	phase = "ready"
	_enable_navigation(true)
	$Card.show()
	_fit_book_ui()
	_fade_ink(1.0,0.12)
	if _pending_close: close()

func close() -> void:
	if not visible or phase == "closing": return
	if phase in ["opening", "turning"]:
		_pending_close = true
		return
	_motion("closing", "OpenBook", true)

func _refresh_if_open() -> void:
	if visible:
		var remembered := selected_species
		_refresh()
		if phase == "ready" and not remembered.is_empty(): _select_species(remembered)

func _stats(species: FishSpecies) -> Dictionary:
	return collection.stats(species.id) if selected_map.is_empty() else _map_stats.get(String(species.id), {"count":0,"best":0.0})

func _refresh() -> void:
	for tile in rows.get_children(): tile.free()
	selected_species = ""
	details.hide()
	var definitions: Array = Progress.species_for(selected_map)
	_map_stats = Progress.map_records(profile.data, selected_map) if profile != null and not selected_map.is_empty() else {}
	filtered_species.clear()
	var discovered := 0
	for species in definitions:
		var known: bool = _stats(species).count > 0
		if known: discovered += 1
		if known and $Card/Content/Filters/OnlyMissing.button_pressed: continue
		filtered_species.append(species)
	page_count = maxi(1, ceili(filtered_species.size() / float(PER_PAGE)))
	page = clampi(page, 0, page_count - 1)
	for index in range(page * PER_PAGE, mini((page + 1) * PER_PAGE, filtered_species.size())):
		var species: FishSpecies = filtered_species[index]
		var tile := Tile.instantiate()
		rows.add_child(tile)
		tile.bind(species, _stats(species), map_history_enabled, not selected_map.is_empty())
	$Card/Content/Header/Summary.text = "จับได้ %d / %d ชนิด · ยังขาด %d" % [discovered, definitions.size(), definitions.size()-discovered]
	$Card/Content/PageHint.text = "ปัดซ้าย–ขวาเพื่อพลิกหน้า · %d / %d" % [page + 1, page_count]
	$Card/Content/Filters/Empty.visible = filtered_species.is_empty()
	$Card/Content/SaveStatus.text = collection.save_error
	$Card/Content/SaveStatus.visible = not collection.save_error.is_empty()
	_refresh_ribbons()
	_fit_grid()

func _refresh_ribbons() -> void:
	for index in $Card/Content/MapTabs.get_child_count():
		var map_id := _ribbon_ids[index]
		var button: Button = $Card/Content/MapTabs.get_child(index)
		var short_names := {"":"ทั้งหมด","river":"แม่น้ำ","lotus_marsh":"บึงบัว","forest_stream":"ลำธาร","wild_reservoir":"เขื่อน","mangrove_estuary":"ป่าชายเลน","coral_coast":"ทะเล"}
		button.text = short_names.get(map_id,RegionCatalog.find(map_id).get("name",map_id))
		button.tooltip_text = "ปลาทั้งหมด" if map_id.is_empty() else RegionCatalog.find(map_id).name
		button.set_pressed_no_signal(map_id == selected_map)

func select_map(index: int) -> void:
	if phase not in ["ready", "hidden"]: return
	if index < 0 or index >= _ribbon_ids.size(): return
	selected_map = _ribbon_ids[index]
	page = 0
	_refresh()

func _on_map_tab_changed(index: int) -> void: select_map(index)

func _enable_navigation(enabled: bool) -> void:
	for ribbon in $Card/Content/MapTabs.get_children():
		# Keep bookmark artwork and selection visible while a page animation owns input.
		var style := "pressed" if ribbon.button_pressed else "normal"
		ribbon.add_theme_stylebox_override("disabled",ribbon.get_theme_stylebox(style))
		ribbon.add_theme_color_override("font_disabled_color",ribbon.get_theme_color("font_pressed_color" if ribbon.button_pressed else "font_color"))
		ribbon.disabled = not enabled
	$Card/Content/Filters/OnlyMissing.disabled = not enabled
	details.get_node("History").disabled = not enabled

func _on_missing_toggled(_enabled: bool) -> void:
	if phase not in ["ready", "hidden"]:
		$Card/Content/Filters/OnlyMissing.set_pressed_no_signal(not _enabled)
		return
	page = 0
	_refresh()

func _select_species(id: String) -> void:
	var species: FishSpecies
	for candidate in filtered_species:
		if String(candidate.id) == id: species = candidate; break
	if species == null: return
	selected_species = id
	for tile in rows.get_children(): tile.set_selected(tile.species_id == id)
	var stats := _stats(species)
	var known: bool = stats.count > 0
	details.show()
	details.get_node("Name").text = species.display_name if known else "ยังไม่ค้นพบ"
	details.get_node("Portrait").texture = species.collection_icon
	details.get_node("Portrait").material = null if known else Silhouette
	details.get_node("Stats").text = ("น้ำหนักสูงสุด %.2f กก.\nจำนวนที่จับได้ %d ตัว" % [stats.best,stats.count] if selected_map.is_empty() else "น้ำหนักสูงสุดในแผนที่นี้\n%.2f กก." % stats.best) if known else "จับปลาชนิดนี้เพื่อบันทึกลงสมุด"
	var baits: Array[String] = []
	var names := {"worm":"ไส้เดือน", "dough":"แป้ง", "lure":"เหยื่อปลอม"}
	for bait in species.bait_preferences: baits.append(names.get(bait,bait))
	details.get_node("Guide").text = "เหยื่อ: %s\nความลึกที่ชอบ %.1f–%.1f ม." % [", ".join(baits), species.preferred_depth.x, species.preferred_depth.y] if known else ""
	details.get_node("History").visible = known and map_history_enabled

func _on_history_pressed() -> void:
	if phase == "ready" and not selected_species.is_empty(): history_requested.emit(selected_species)

func turn_page(direction: int) -> void:
	if phase != "ready": return
	var target := clampi(page + direction, 0, page_count - 1)
	if target == page: return
	_next_page = target
	_motion("turning", "TurnPage", direction < 0)

func _gesture_area(point: Vector2) -> bool:
	if $Card/Content/Header/Close.get_global_rect().has_point(point): return false
	if $Card/Content/Filters/OnlyMissing.get_global_rect().has_point(point): return false
	if details.visible and details.get_node("History").visible and details.get_node("History").get_global_rect().has_point(point): return false
	return $Card/Content/Scroll.get_global_rect().has_point(point) or (point.x > details.global_position.x and $Card/Content.get_global_rect().has_point(point))

func _begin(point: Vector2, finger: int) -> bool:
	if _finger != -2 or not _gesture_area(point): return false
	_finger = finger
	_start = point
	_travel = 0.0
	return true

func _drag(point: Vector2) -> void:
	_travel = maxf(_travel, _start.distance_to(point))

func _release(point: Vector2) -> void:
	_drag(point)
	_finger = -2
	var delta := point - _start
	if absf(delta.x) >= 48.0 and absf(delta.x) > absf(delta.y) * 1.3:
		turn_page(1 if delta.x < 0 else -1)
	elif _travel <= 12.0:
		for tile in rows.get_children():
			if tile.get_global_rect().has_point(point):
				_select_species(tile.species_id)
				break

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if phase != "ready": return
	var handled := false
	if event is InputEventScreenTouch:
		if event.pressed: handled = _begin(event.position,event.index)
		elif event.index == _finger:
			if event.canceled: _finger = -2
			else: _release(event.position)
			handled = true
	elif event is InputEventScreenDrag and event.index == _finger:
		_drag(event.position)
		handled = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1:
		if event.pressed: handled = _begin(event.position,-1)
		elif _finger == -1:
			_release(event.position)
			handled = true
	elif event is InputEventMouseMotion and _finger == -1:
		_drag(event.position)
		handled = true
	if handled: get_viewport().set_input_as_handled()
