extends SceneTree

var errors := 0

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  errors += 1

func make_fish() -> FishState:
 var fish := FishState.new()
 fish.species = load("res://data/fish/tilapia.tres")
 fish.weight = 2.0
 fish.id = 1
 fish.position = Vector3(0, 1, -15)
 return fish

func run() -> void:
 for species in FishCatalog.SPECIES:
  var fresh: Vector2 = species.fight_zones(species.max_weight, 1.0, 1.35)
  var tired: Vector2 = species.fight_zones(species.max_weight, 0.1, 1.35)
  var resting: Vector2 = species.fight_zones(species.max_weight, 1.0, 0.42)
  expect(1.0 - fresh.y > fresh.x - 0.15, String(species.id) + ": fresh red zone is larger than green")
  expect(tired.y > fresh.y and tired.x > fresh.x, String(species.id) + ": fatigue shrinks red and expands green")
  expect(fresh.y < resting.y and fresh.y > fresh.x, String(species.id) + ": surges enlarge red while retaining a yellow window")
 var green_fish := make_fish()
 var yellow_fish := make_fish()
 var green := FightSimulation.new()
 var yellow := FightSimulation.new()
 green.line_length = 16.0
 yellow.line_length = 16.0
 var tuning := FishingTuning.new()
 for tick in 100:
  green.update_zones(green_fish)
  yellow.update_zones(yellow_fish)
  green.tension = green.yellow_start - 0.04
  yellow.tension = (yellow.yellow_start + yellow.red_start) * 0.5
  green.advance(0.02, Vector3.ZERO, green_fish, Vector2.ZERO, tuning)
  yellow.advance(0.02, Vector3.ZERO, yellow_fish, Vector2(0, 0.2), tuning)
 expect(Vector2(green_fish.position.x, green_fish.position.z).length() > 15.5, "fish actually escapes farther during green tension")
 expect(green_fish.position.length() > yellow_fish.position.length(), "green loses more distance than yellow control")
 expect(yellow_fish.stamina < green_fish.stamina, "maintaining yellow tires fish faster than green")
 var neutral_fish := make_fish()
 var neutral := FightSimulation.new()
 neutral.line_length = 16.0
 neutral.update_zones(neutral_fish)
 neutral.tension = (neutral.yellow_start + neutral.red_start) * 0.5
 neutral.advance(0.02, Vector3.ZERO, neutral_fish, Vector2.ZERO, tuning)
 expect(neutral_fish.position.z > -15.0, "holding yellow at neutral always brings the fish closer")
 var hard_fish := make_fish()
 hard_fish.species = load("res://data/fish/giant_catfish.tres")
 hard_fish.weight = 25
 var hard := FightSimulation.new()
 hard.update_zones(hard_fish)
 expect(hard.red_start - hard.yellow_start < neutral.red_start - neutral.yellow_start, "harder fish have narrower yellow control windows")
 var other_fish := make_fish()
 other_fish.id = 37
 var other := FightSimulation.new()
 other.update_zones(other_fish)
 expect(not is_equal_approx(other.yellow_width, neutral.yellow_width), "individual fish get a randomized yellow width")
 var saw_surge := false
 var saw_recovery := false
 var surge_range_ok := true
 var previous_surge := false
 for tick in 1500:
  var midpoint := lerpf(hard.yellow_start, hard.red_start, 0.5)
  hard.advance(0.02, Vector3.ZERO, hard_fish, Vector2(0, clampf((midpoint - hard.tension) * 8.0, -1.0, 1.0)), tuning)
  if hard.surge_active:
   saw_surge = true
   surge_range_ok = surge_range_ok and 1.0 - hard.red_start >= 0.699 and 1.0 - hard.red_start <= 0.801
  elif previous_surge:
   saw_recovery = hard.red_start > 0.3
  previous_surge = hard.surge_active
 expect(saw_surge and saw_recovery, "surges occur as short bursts and return to the normal band")
 expect(saw_surge and surge_range_ok, "sudden surges expand red to 70-80 percent")
 print("FISH BEHAVIOR RESULT: ", errors, " failures")
 quit(errors)
