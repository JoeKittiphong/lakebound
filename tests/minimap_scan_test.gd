extends SceneTree
var checks := 0
var failures := 0
var output := "res://exports/minimap-scan-qa"

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1

func frames(count := 6) -> void:
	for i in count: await process_frame

func capture(name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func tap(control: Control, mouse := false) -> void:
	var point := control.get_global_rect().get_center()
	for pressed in [true,false]:
		if mouse:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event,true)
		else:
			var event := InputEventScreenTouch.new()
			event.position = point
			event.index = 6
			event.pressed = pressed
			root.push_input(event,true)
	await frames()

func fixture(position: Vector3) -> FishState:
	var fish := FishState.new()
	fish.species = load("res://data/fish/tilapia.tres")
	fish.position = position
	return fish

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var profile: AnglerProfile = root.get_node("AnglerSave")
	profile.save_path = "user://minimap-scan-test.cfg"
	profile.data = profile.defaults()
	root.get_node("FishCollection").recording_enabled = false
	var game = load("res://features/regions/grand_river.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 30: await physics_frame
	var hud: FishingHUD = game.get_node("HUD/FishingHUD")
	var mini = hud.get_node("SafeArea/Minimap")
	var pond: PondEcosystem = game.get_node("PondEcosystem")
	var player: AnglerPlayer = game.get_node("Player")
	var boat: FishingBoat = game.get_node("FishingBoat")
	game.get_node("FishingController").set_physics_process(false)
	game.get_node("FishingEffects").audio_enabled = false
	hud.get_node("SafeArea/FirstCatch").active = false
	hud.get_node("SafeArea/FirstCatch").hide()
	pond.set_physics_process(false)
	player.set_physics_process(false)
	boat.set_physics_process(false)
	await frames()
	var original_position := player.global_position
	var originals := pond.fish.duplicate()
	expect(mini.ecosystem == pond and not mini.get_node("ScanButton").disabled,"HUD injects the real ecosystem into the minimap scanner")
	expect(mini.view.fish_positions.is_empty(),"no fish dots appear before the player scans")
	expect(mini.view.project(mini.view.player_position).is_equal_approx(mini.view.size*0.5),"player is exactly centered on the local map")
	expect(mini.view.radius_m == 100.0,"local map covers a 100 metre radius")
	var span: Vector2 = mini.get_node("Content/View/Terrain").material.get_shader_parameter("span_uv")
	expect(span.is_equal_approx(Vector2(.2,.4)),"1000x500 map is sampled over a 200x200 metre local window")
	expect(not mini._has_point(Vector2(1,1)) and mini._has_point(Vector2(98,104)),"transparent map corners do not capture gameplay clicks")
	for label in mini.find_children("*","Label",true,false):
		expect(not "100" in label.text,"no numeric range label is displayed")
	await capture("minimap-before-scan")
	await tap(mini.get_node("ScanButton"))
	expect(mini.view.fish_positions.size() > 0,"normal live shore scan detects the existing population")
	await capture("minimap-live-shore-scan")
	# Deterministic radial boundary cases, independent of randomized population layout.
	player.global_position = Vector3.ZERO
	mini._sync_player()
	pond.fish.clear()
	var near := fixture(Vector3(20,4,-10))
	var edge := fixture(Vector3(100,3,0))
	var diagonal := fixture(Vector3(-60,8,80))
	var outside := fixture(Vector3(100.2,2,0))
	var square_only := fixture(Vector3(90,2,90))
	var invalid := fixture(Vector3(INF,2,0))
	pond.fish.assign([near,edge,diagonal,outside,square_only,invalid])
	pond.population_changed.emit()
	await tap(mini.get_node("ScanButton"))
	expect(mini.view.fish_positions.size() == 3,"scan includes the circular boundary but excludes square corners, beyond-range and invalid fish")
	expect(not paused and not hud.get_node("MapPanel").visible,"touching Scan does not also open the large map or pause play")
	expect(mini.get_node("ScanFeedback").text == "พบปลา","scanner reports a nonempty result")
	var right: Vector2 = mini.view.project(Vector2(100,0))
	expect(right.is_equal_approx(Vector2(mini.view.size.x,mini.view.size.y*.5)),"100 metre east projects to the circular edge")
	expect(mini.view.project(Vector2(0,-100)).is_equal_approx(Vector2(mini.view.size.x*.5,0)),"negative world Z remains north")
	near.position = Vector3(35,5,-15)
	mini._process(.2)
	expect(mini.view.fish_positions.has(Vector2(35,-15)),"scanned dots follow real fish movement")
	pond.keep(near)
	expect(not mini.view.fish_positions.has(Vector2(35,-15)),"kept fish disappear immediately from scan results")
	player.global_position = Vector3(10,0,20)
	mini._process(.2)
	expect(mini.view.player_position == Vector2(10,20) and mini.view.project(Vector2(10,20)).is_equal_approx(mini.view.size*.5),"walking pans terrain while the player remains centered")
	mini.scan_duration = .5
	await tap(mini.get_node("ScanButton"),true)
	expect(mini._scan_remaining > 0,"desktop mouse can rescan without a cooldown")
	await create_timer(.7).timeout
	expect(mini.view.fish_positions.is_empty() and mini._scan_remaining == 0,"fish echoes expire instead of leaving stale dots indefinitely")
	pond.fish.clear()
	pond.population_changed.emit()
	await tap(mini.get_node("ScanButton"))
	expect(mini.view.fish_positions.is_empty() and mini.get_node("ScanFeedback").text == "ไม่พบปลา","empty scans give feedback without inventing fish")
	mini.bind(player,"lotus_marsh",pond)
	expect(mini._detected.is_empty() and mini.view.fish_positions.is_empty(),"rebinding a map clears prior scan results")
	player.global_position = Vector3(-90,0,-88)
	mini._sync_player()
	expect(mini.view.project(Vector2(-90,-88)).is_equal_approx(mini.view.size*.5),"player stays centered even at the map boundary")
	var uv: Vector2 = mini.get_node("Content/View/Terrain").material.get_shader_parameter("player_uv")
	expect(uv.is_equal_approx(Vector2.ZERO),"map-edge UV is not clamped or wrapped to the opposite shore")
	mini.bind(player,"river",pond)
	player.global_position = boat.global_position + Vector3(2,0,0)
	boat.set_deployed(true) # Scanner/passenger fixture, not a free gameplay boat.
	expect(boat.board(player),"fixture boards the real boat")
	boat.global_position += Vector3(15,0,-6)
	boat.rotation.y = .7
	boat._sync_passenger()
	mini._process(.2)
	var aboard := Vector2(player.global_position.x,player.global_position.z)
	expect(mini.view.player_position.is_equal_approx(aboard) and mini.view.project(aboard).is_equal_approx(mini.view.size*.5),"minimap follows the actual passenger anchor while boating")
	expect(is_equal_approx(mini.view.player_yaw,boat.global_rotation.y),"heading follows the boat driver instead of remaining frozen")
	# Restore the real population and render actual scan results for the review capture.
	boat.passenger = null
	boat.mode = FishingBoat.Mode.MOORED
	player.disembark(original_position)
	pond.fish.assign(originals)
	pond.population_changed.emit()
	mini.scan_duration = 6.0
	mini._sync_player()
	await tap(mini.get_node("ScanButton"))
	expect(mini.view.fish_positions.size() > 0,"the real rainforest lake has detectable fish near the starting shore")
	await capture("minimap-real-scan")
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1024,768)]:
		root.size = dimensions
		await frames()
		expect(hud.get_global_rect().encloses(mini.get_global_rect()),"circular widget fits viewport " + str(dimensions))
		expect(not mini.get_global_rect().intersects(hud.get_node("SafeArea/RankingButton").get_global_rect()),"scanner does not cover ranking at " + str(dimensions))
		expect(not mini.get_global_rect().intersects(hud.get_node("SafeArea/TopBar").get_global_rect()),"scanner does not cover top actions at " + str(dimensions))
		await capture("minimap-layout-%d" % dimensions.x)
	root.size = Vector2i(1280,720)
	await frames()
	await tap(mini)
	expect(hud.get_node("MapPanel").visible and paused,"tapping the circular map still opens the full map")
	hud.get_node("MapPanel").close()
	expect(not paused,"closing the full map restores gameplay")
	game.queue_free()
	current_scene = null
	await process_frame
	print("MINIMAP SCAN RESULT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
