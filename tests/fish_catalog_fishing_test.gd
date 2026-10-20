extends SceneTree

const Catalog = preload("res://data/fish/fish_catalog.gd")
const Gameplay = preload("res://features/gameplay/gameplay.tscn")
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 for definition in Catalog.SPECIES:
  var scene := Gameplay.instantiate()
  root.add_child(scene)
  scene.set_process(false)
  var player: Node3D = scene.get_node("Player")
  player.set_physics_process(false)
  var pond: Node = scene.get_node("PondEcosystem")
  pond.set_physics_process(false)
  var one_species: Array[Resource] = [definition]
  pond.species = one_species
  pond.reset_population(4207)
  var fishing: Node = scene.get_node("FishingController")
  fishing.set_physics_process(false)
  fishing.haptics_enabled = false
  scene.get_node("HUD/FishingHUD").set_process(false)
  scene.get_node("FishingEffects").set_process(false)
  scene.get_node("FishingEffects").audio_enabled = false
  fishing.selected_bait = StringName(definition.bait_preferences[0])
  fishing.selected_depth = (definition.preferred_depth.x + definition.preferred_depth.y) * 0.5
  fishing.cast()
  for tick in 600:
   pond.step(0.15)
   fishing.advance(0.15, player.position)
   if fishing.state == fishing.State.BITE:
    break
  var landed := false
  if fishing.strike():
   for tick in 7200:
    fishing.rod_input = Vector2(-fishing.lateral_direction, 1.0 if fishing.tension < 0.72 else -0.72).limit_length(1.0)
    fishing.advance(1.0 / 60.0, player.position)
    if fishing.state == fishing.State.RESULT:
     landed = true
     break
    if fishing.state == fishing.State.LOST:
     break
  if not landed:
   failures += 1
   push_error("Could not land " + String(definition.id) + ": " + fishing.feedback)
  else:
   print("LANDED SPECIES: ", definition.id, " in ", snappedf(fishing.fight_time, 0.1), "s")
   var identity: int = fishing.active_fish.id
   var fish: RefCounted = fishing.active_fish
   fishing.resolve_catch(false)
   if not pond.fish.has(fish) or fish.id != identity:
    failures += 1
  scene.free()
 for tick in 3:
  await process_frame
 print("CATALOG FISHING RESULT: 16 species, ", failures, " failures")
 quit(0 if failures == 0 else 1)
