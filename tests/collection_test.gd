extends SceneTree

var errors := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR") if not OS.get_environment("LAKEBOUND_QA_DIR").is_empty() else "res://exports/qa/screenshots"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		errors += 1

func run() -> void:
	var collection := root.get_node("FishCollection")
	var test_save_path := output + "/collection-test-%d.cfg" % OS.get_process_id()
	collection.save_path = test_save_path
	DirAccess.remove_absolute(collection.save_path)
	collection.load_records()
	expect(collection.records.is_empty(), "new player starts undiscovered")
	var scene = load("res://features/gameplay/gameplay.tscn").instantiate()
	# This suite exercises the direct collection path; journal settlement has
	# separate coverage. Keep its profile/tutorial writes isolated from players.
	scene.economy_enabled = false
	scene.get_node("HUD/FishingHUD/SafeArea/FirstCatch").save_path = output + "/collection-tutorial.cfg"
	root.add_child(scene)
	current_scene = scene
	var fishing = scene.get_node("FishingController")
	var pond = scene.get_node("PondEcosystem")
	scene.get_node("FishingEffects").audio_enabled = false
	var hud = scene.get_node("HUD/FishingHUD")
	hud.get_node("SafeArea/FirstCatch").active = false
	hud.get_node("SafeArea/FirstCatch").hide()
	fishing.set_physics_process(false)
	pond.set_physics_process(false)
	var fish = pond.fish[0]
	fish.weight = 1.2
	fishing.active_fish = fish
	fishing._change_state(fishing.State.RESULT)
	fishing.fish_landed.emit(fish)
	expect(collection.stats(fish.species.id).count == 1, "landed catch records before keep/release choice")
	fishing.resolve_catch(false)
	expect(collection.stats(fish.species.id).count == 1, "release does not count twice")
	fish.weight = 2.4
	fishing.active_fish = fish
	fishing._change_state(fishing.State.RESULT)
	fishing.fish_landed.emit(fish)
	fishing.resolve_catch(true)
	expect(collection.stats(fish.species.id).count == 2, "keeping also counts once")
	fish.weight = 0.6
	collection.record_catch(fish)
	collection.load_records()
	var stats: Dictionary = collection.stats(fish.species.id)
	expect(stats.count == 3 and is_equal_approx(stats.total, 4.2) and is_equal_approx(stats.best, 2.4) and is_equal_approx(stats.smallest, 0.6) and is_equal_approx(stats.last, 0.6), "save reload preserves all statistics and replacement saves")
	await process_frame
	var collection_button: Button = hud.get_node("SafeArea/TopBar/Actions/CollectionButton")
	var open_point := collection_button.get_global_rect().get_center()
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = open_point
		touch.pressed = pressed
		root.push_input(touch, true)
		await process_frame
	var panel: Control = hud.get_node("CollectionPanel")
	expect(paused and panel.visible, "collection button opens a paused book modal")
	await create_timer(0.7).timeout
	expect(panel.rows.columns == 5 and panel.rows.get_child_count() == 15, "book shows five fish per row and a bounded page")
	expect(not panel.details.visible, "detail page starts blank")
	var atlas_paths := {}
	var seen := 0
	for page_index in panel.page_count:
		if page_index > 0:
			panel.turn_page(1)
			await create_timer(0.9).timeout
		for tile in panel.rows.get_children():
			var icon: TextureRect = tile.get_node("Content/Preview")
			var definition: FishSpecies = collection.Catalog.find(tile.species_id)
			expect(icon.texture == definition.collection_icon, String(definition.id) + " retains its catalog portrait")
			expect(icon.texture is AtlasTexture and tile.find_children("*", "SubViewport", true, false).is_empty(), "fish tile reuses a 2D atlas")
			if icon.texture is AtlasTexture: atlas_paths[icon.texture.atlas.resource_path] = true
			var known: bool = collection.stats(definition.id).count > 0
			expect(tile.revealed == known and tile.get_node("Content/Preview/Question").visible == not known, "discovery presentation stays correct")
			seen += 1
	expect(seen == collection.SPECIES.size() and atlas_paths.size() == 2, "swipe pages cover the complete catalog and reuse both atlases")
	var caught_index := 0
	for index in panel.filtered_species.size():
		if panel.filtered_species[index].id == fish.species.id: caught_index = index
	panel.turn_page(int(caught_index / panel.PER_PAGE) - panel.page)
	await create_timer(0.9).timeout
	var tile: Control = panel.rows.get_child(caught_index % panel.PER_PAGE)
	var point := tile.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 12
		event.pressed = pressed
		event.position = point
		root.push_input(event,true)
	await process_frame
	expect(panel.details.visible and "2.40" in panel.details.get_node("Stats").text, "tap reveals the real personal best on the right")
	for viewport_size in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1920,864)]:
		root.size = viewport_size
		for tick in 6: await process_frame
		var close_button: Button = panel.get_node("Card/Content/Header/Close")
		expect(panel.get_node("Card").get_global_rect().encloses(close_button.get_global_rect()), "close target stays inside book")
		expect(panel.rows.columns == 5 and panel.rows.get_child_count() <= 15, "responsive layout preserves five-column paging")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output + "/collection-%d.png" % viewport_size.x)
	panel.close()
	expect(paused, "closing animation retains the session pause")
	await panel.closed
	await process_frame
	expect(not paused and not panel.visible, "closing the book restores play")
	collection.records.clear()
	collection.load_records()
	expect(collection.stats(fish.species.id).count == 3, "collection records remain persisted after book navigation")
	scene.free()
	current_scene = null
	await process_frame
	print("COLLECTION RESULT: ", errors, " failures")
	quit(errors)
