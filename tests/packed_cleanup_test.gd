extends SceneTree
var failures = 0
var checks = 0
func _initialize():
	call_deferred("run")
func expect(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+label)
func run():
	var qa = OS.get_environment("LAKEBOUND_QA_DIR")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(qa.path_join("reachability.json")))
	for path in manifest.export_resources:
		expect(ResourceLoader.exists(path),"packed resource present: "+path)
	var profile = root.get_node("AnglerSave")
	profile.data = profile.defaults()
	profile.data.identity.name = "QA Tester"
	root.get_node("FishCollection").recording_enabled = false
	var loading = load("res://features/loading/loading.tscn").instantiate()
	root.add_child(loading)
	current_scene = loading
	await create_timer(.3).timeout
	expect(loading.cinematic.get_node_or_null("Scenery/LoadingJungle") != null,"packed loading rainforest")
	loading.queue_free()
	await process_frame
	for entry in RegionCatalog.MAPS:
		var packed = load(entry.scene)
		expect(packed != null,"map loads: "+entry.id)
		if packed == null:continue
		var game = packed.instantiate()
		game.economy_enabled = false
		root.add_child(game)
		current_scene = game
		game.get_node("FishingEffects").audio_enabled = false
		for frame in 8:await physics_frame
		expect(game.map_id == entry.id,"packed map identity: "+entry.id)
		expect(game.get_node("PondEcosystem").species.size() == entry.fish_count,"packed fish roster: "+entry.id)
		expect(game.get_node("HUD/FishingHUD") != null,"packed HUD: "+entry.id)
		game.queue_free()
		current_scene = null
		for frame in 3:await process_frame
	var menu = load("res://features/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	for frame in 3:await process_frame
	var carousel = menu.get_node("SafeArea/PlayCard/Content/MapCarousel")
	for entry in RegionCatalog.MAPS:
		carousel.set_region(entry.id,true)
		expect(carousel.get_node("%Picture").texture != null,"packed map picture: "+entry.id)
	print("PACKED CLEANUP RESULT: ",checks," checks, ",failures," failures")
	menu.queue_free()
	await process_frame
	call_deferred("finish")

func finish():
	for frame in 8:await process_frame
	quit(1 if failures else 0)
