extends SceneTree

var failures := 0
func _initialize() -> void:
 call_deferred("run")
func expect(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1
func fish_record() -> FishState:
 var fish := FishState.new()
 fish.species = load("res://data/fish/tilapia.tres")
 fish.weight = 2.0
 fish.id = 17
 fish.position = Vector3(0, 1, -15)
 return fish
func run() -> void:
 var rig: AnglerCameraRig = load("res://features/gameplay/camera_rig.tscn").instantiate()
 root.add_child(rig)
 rig.rotate_view(Vector2(0, -100000))
 expect(is_equal_approx(rad_to_deg(rig.rotation.x), 15.0), "maximum downward drag clamps the rig at 15 degrees")
 var camera: Camera3D = rig.get_node("Camera3D")
 expect(camera.global_position.y - rig.global_position.y > 2.0, "maximum pitch keeps the camera above the player's ground plane")
 var definition: RiverDefinition = load("res://world/river/river_definition.tres")
 var lowest_clearance := INF
 for z in [-100.0, -40.0, 42.0, 90.0, 110.0]:
  for side in [-1.0, 1.0]:
   for distance in [2.0, 8.0, 25.0]:
    var x: float = definition.center_at(z) + side * (definition.half_width_at(z) + distance)
    rig.position = Vector3(x, definition.ground_height(Vector2(x, z)) + 0.05, z)
    for yaw in range(0, 360, 30):
     rig.rotation.y = deg_to_rad(yaw)
     var p := camera.global_position
     lowest_clearance = minf(lowest_clearance, p.y - definition.ground_height(Vector2(p.x, p.z)))
 expect(lowest_clearance > 0.25, "maximum pan remains clear of river terrain across both banks and camera headings")
 rig.rotate_view(Vector2(0, 100000))
 expect(is_equal_approx(rad_to_deg(rig.rotation.x), rig.min_pitch), "opposite vertical pan still respects its limit")
 var widths_ok := true
 for species in FishCatalog.SPECIES:
  for weight in [species.min_weight, species.max_weight]:
   for stamina in [1.0, 0.1]:
    for activity in [0.42, 1.35, 1.5, 2.7]:
     var zones: Vector2 = species.fight_zones(weight, stamina, activity)
     widths_ok = widths_ok and zones.y - zones.x >= 0.1799
 expect(widths_ok, "all species retain at least 18 percent yellow, including heavy fish and surges")
 var sampled_ok := true
 for species in FishCatalog.SPECIES:
  var fish := fish_record()
  fish.species = species
  fish.weight = species.max_weight
  var fight := FightSimulation.new()
  fight.update_zones(fish)
  sampled_ok = sampled_ok and fight.red_start - fight.yellow_start >= 0.1799
 expect(sampled_ok, "individual randomized fight zones retain the same mobile minimum")
 for zone in ["yellow", "green", "red"]:
  for reel in [0.0, 0.5]:
   var old_fish := fish_record()
   var new_fish := fish_record()
   var old := FightSimulation.new()
   var newer := FightSimulation.new()
   old.line_length = 30
   newer.line_length = 30
   old.update_zones(old_fish)
   newer.update_zones(new_fish)
   var value := (old.yellow_start + old.red_start) * 0.5
   if zone == "green":value = old.yellow_start - 0.03
   if zone == "red":value = old.red_start + 0.05
   old.tension = value
   newer.tension = value
   var previous_tuning := FishingTuning.new()
   previous_tuning.yellow_retrieve_multiplier = 1.8
   var tuning := FishingTuning.new()
   old.advance(0.001, Vector3.ZERO, old_fish, Vector2(0, reel), previous_tuning)
   newer.advance(0.001, Vector3.ZERO, new_fish, Vector2(0, reel), tuning)
   var gain_old := 15.0 - Vector2(old_fish.position.x, old_fish.position.z).length()
   var gain_new := 15.0 - Vector2(new_fish.position.x, new_fish.position.z).length()
   if zone == "yellow":
    expect(gain_old > 0 and absf(gain_new / gain_old - 2.0) < 0.02, "yellow retrieves twice the previous distance, reel input %.1f" % reel)
   else:
    expect(old_fish.position.distance_to(new_fish.position) < 0.00001, "%s-zone movement is unaffected by yellow retrieve boost" % zone)
 rig.queue_free()
 await process_frame
 print("MOBILE FISHING TUNING RESULT: ", failures, " failures")
 quit(failures)
