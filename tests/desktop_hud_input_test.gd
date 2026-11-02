extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1

func frames(count := 6) -> void:
	for i in count:
		await process_frame

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	root.push_input(move,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event,true)
	await frames()

func run() -> void:
	var profile: AnglerProfile = root.get_node("AnglerSave")
	profile.save_path = "user://desktop-input-test.cfg"
	profile.data = profile.defaults()
	root.get_node("FishCollection").recording_enabled = false
	var game = load("res://features/regions/grand_river.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 30:
		await physics_frame
	var hud: FishingHUD = game.get_node("HUD/FishingHUD")
	game.get_node("FishingController").set_physics_process(false)
	game.get_node("FishingEffects").audio_enabled = false
	hud.get_node("SafeArea/FirstCatch").active = false
	hud.get_node("SafeArea/FirstCatch").hide()
	await frames()
	expect(not paused and not hud.is_collection_open(), "real rainforest map starts without a stuck modal pause")
	var actions := hud.get_node("SafeArea/TopBar/Actions")
	for entry in [["TackleButton","TacklePanel"],["FishBox/Open","FishStoragePanel"],["MissionButton","MissionPanel"]]:
		await click(actions.get_node(entry[0]))
		var panel: Control = hud.get_node(entry[1])
		expect(panel.visible and paused, "mouse opens " + entry[1])
		if entry[1] == "FishStoragePanel":
			await create_timer(1.0).timeout
		await click(panel.get_node("Card/Content/Header/Close"))
		for i in 180:
			if not panel.visible:
				break
			await process_frame
		expect(not panel.visible and not paused, "mouse closes " + entry[1] + " and restores play")
	await click(actions.get_node("CollectionButton"))
	var book: Control = hud.get_node("CollectionPanel")
	for i in 180:
		if book.phase == "ready":
			break
		await process_frame
	expect(book.visible and book.phase == "ready" and paused, "mouse opens the 3D Collection book")
	await click(book.rows.get_child(0))
	expect(book.details.visible, "mouse selects a fish without losing input")
	await click(book.get_node("Card/Content/Header/Close"))
	for i in 180:
		if not book.visible:
			break
		await process_frame
	expect(not book.visible and not paused and hud.get_node("SafeArea").visible, "closing Collection restores visible usable HUD")
	await click(actions.get_node("SettingsButton"))
	var settings: Control = hud.get_node("GameSettingsPanel")
	expect(settings.visible and paused, "mouse opens settings after Collection")
	await click(settings.get_node("%Resume"))
	expect(not settings.visible and not paused, "mouse Resume restores the actual game")
	game.queue_free()
	current_scene = null
	await process_frame
	print("DESKTOP HUD INPUT RESULT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
