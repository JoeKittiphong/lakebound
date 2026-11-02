extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok: failures += 1

func run() -> void:
 var preview: Node3D = load("res://tests/previews/surface_spray_preview.tscn").instantiate()
 root.add_child(preview)
 var spray = preview.get_node("SurfaceSpray")
 var fish := FishState.new()
 fish.id = 900
 fish.species = preload("res://data/fish/fish_catalog.gd").SPECIES[0]
 fish.state = &"chasing_lure"
 fish.weight = 4.0
 fish.position = Vector3(0, 0.12, 0)
 var fish_list: Array = [fish]
 var viewer := Vector3.ZERO
 spray.advance(0.15, Vector3(0, 0.12, 0), true, fish_list, viewer)
 spray.advance(0.15, Vector3(0, 0.12, 0), true, fish_list, viewer)
 expect(spray.emitted_count == 0, "stationary lure and fish do not spray")
 spray.advance(0.15, Vector3(0.12, 0.12, 0), true, fish_list, viewer)
 expect(spray.emitted_count == 1, "surface retrieve emits spray")
 var slow: float = spray.last_strength
 spray.advance(0.15, Vector3(0.6, 0.12, 0), true, fish_list, viewer)
 expect(spray.last_strength > slow, "faster retrieve increases spray strength")
 var before: int = spray.emitted_count
 spray.advance(0.15, Vector3(0.9, 2.0, 0), true, fish_list, viewer)
 expect(spray.emitted_count == before, "deep lure emits no surface spray")
 fish.position.x += 0.06
 spray.advance(0.15, Vector3(0.9, 2.0, 0), true, fish_list, viewer)
 var gentle: float = spray.last_strength
 fish.position.x += 0.5
 spray.advance(0.45, Vector3(0.9, 2.0, 0), true, fish_list, viewer)
 expect(spray.emitted_count > before and spray.last_strength > gentle, "chasing fish splashes according to actual speed")
 before = spray.emitted_count
 fish.position.y = 2.0
 fish.position.x += 0.6
 spray.advance(0.45, Vector3(0.9, 2.0, 0), true, fish_list, viewer)
 spray.strike(fish.position, fish.weight)
 expect(spray.emitted_count == before, "deep fish swimming and biting do not spray above water")
 spray.strike(Vector3(0, 0.12, 0), 4.0)
 expect(spray.emitted_count == before + 1 and spray.last_strength > 1.0, "surface strike makes a stronger splash")
 before = spray.emitted_count
 spray.emit_spray(Vector3(100, 0.12, 0), Vector3.ZERO, 1.0)
 expect(spray.emitted_count == before, "distant splashes are culled")
 spray.advance(1.0, Vector3.ZERO, false, [], viewer)
 spray.advance(0.15, Vector3(20, 0.12, 0), true, [], viewer)
 expect(spray.emitted_count == before, "new cast does not draw a spray trail from previous cast")
 for index in 40: spray.emit_spray(Vector3.ZERO, Vector3.ZERO, 1.5)
 expect(spray.get_child_count() == 8 and spray.emitted_count - before <= 8, "burst storm keeps fixed eight-emitter budget")
 before = spray.emitted_count
 spray.strike(Vector3(0, 0.12, 0), 4.0)
 expect(spray.emitted_count == before + 1, "strike splash survives a full pursuit spray pool")
 for burst in spray.get_children():
  expect(burst.amount <= 30, "particle budget per burst <= 30")
 # Verify the actual gameplay scene supplies the existing water deformation system.
 var game: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 expect(game.get_node("FishingEffects").water_interactions == game.get_node("WaterInteractions"), "gameplay connects spray to real surface waves")
 game.free()
 for entry in RegionCatalog.MAPS:
  var region: Node3D = load(entry.scene).instantiate()
  expect(region.get_node("FishingEffects").water_interactions == region.get_node("WaterInteractions"), "surface wave connection: " + str(entry.id))
  region.free()
 if DisplayServer.get_name() != "headless":
  root.size = Vector2i(1280, 720)
  var camera: Camera3D = preview.get_node("Camera")
  camera.look_at(Vector3(0, 0, 0))
  preview.get_node("Fish").setup(fish)
  preview.get_node("Fish").position = Vector3(-0.7, -0.2, 0.1)
  preview.get_node("Lure").position = Vector3(0.7, -0.18, 0)
  for child in preview.get_node("Lure").get_children(): child.visible = child.name == "Frog"
  await create_timer(0.75).timeout
  spray.advance(1.0, Vector3.ZERO, false, [], viewer)
  spray.emit_spray(Vector3(-0.7, 0.12, 0.1), Vector3(2, 0, 0), 1.25)
  spray.emit_spray(Vector3(0.7, 0.12, 0), Vector3(1, 0, 0), 0.5)
  await create_timer(0.12).timeout
  await RenderingServer.frame_post_draw
  var output := "res://exports/qa-surface-spray"
  DirAccess.make_dir_recursive_absolute(output)
  root.get_texture().get_image().save_png(output + "/chase-and-retrieve.png")
  await create_timer(0.16).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output + "/tailbeat-propagation.png")
 preview.queue_free()
 await process_frame
 await test_gameplay()
 print("SURFACE SPRAY RESULT: ", failures, " failures")
 quit(failures)

func test_gameplay() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.data.equipped.bait = "frog"
 root.get_node("FishCollection").recording_enabled = false
 var game: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 game.economy_enabled = false
 root.add_child(game)
 current_scene = game
 game.set_process(false)
 var controller: FishingController = game.get_node("FishingController")
 var ecosystem: PondEcosystem = game.get_node("PondEcosystem")
 var player: Node3D = game.get_node("Player")
 var effects = game.get_node("FishingEffects")
 var water = game.get_node("WaterInteractions")
 game.get_node("HUD").hide()
 game.get_node("HUD/FishingHUD").set_process(false)
 game.get_node("CameraRig").set_process(false)
 player.set_physics_process(false)
 controller.set_physics_process(false)
 ecosystem.set_physics_process(false)
 effects.set_process(false)
 effects.audio_enabled = false
 water.set_process(false)
 controller.bind_profile(profile)
 var point := ecosystem.constrain_to_water(player.global_position + Vector3(9, 0, 0))
 point.y = 0.12
 controller.cast_position = point
 controller.state = controller.State.WAITING
 var chaser: FishState = ecosystem.fish[0]
 for record in ecosystem.fish:
  record.state = &"roaming"
  record.position.y = 4.0
 chaser.position = point + Vector3(-0.9, 0, 0.15)
 chaser.state = &"chasing_lure"
 ecosystem.bait_active = true
 effects._process(0.15)
 controller.cast_position.x += 0.18
 chaser.position.x += 0.35
 effects._process(0.15)
 var spray = effects.get_node("SurfaceSpray")
 expect(spray.emitted_count >= 2, "real fishing effects drive both retrieve and chase sprays")
 expect(water.emitted_count >= 2, "sprays also disturb the real river water")
 var count: int = spray.emitted_count
 controller._on_fish_biting(chaser)
 expect(spray.emitted_count == count + 1, "real bite signal triggers surface splash")
 if DisplayServer.get_name() != "headless":
  var camera: Camera3D = game.get_node("CameraRig/Camera3D")
  var surface := Vector3(point.x, -0.18, point.z)
  camera.global_position = surface + Vector3(3, 2.6, 4)
  camera.look_at(surface)
  water._process(0.16)
  await create_timer(0.12).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-surface-spray/river-strike.png")
 game.queue_free()
 await process_frame
 await process_frame
