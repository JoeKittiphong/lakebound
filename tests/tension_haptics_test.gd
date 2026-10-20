extends SceneTree

var errors := 0

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  errors += 1

func run() -> void:
 var controller := FishingController.new()
 var fish := FishState.new()
 fish.species = load("res://data/fish/giant_catfish.tres")
 fish.weight = 25.0
 controller.active_fish = fish
 controller._change_state(controller.State.FIGHT)
 var pulses: Array[int] = []
 controller.haptic_requested.connect(func(duration: int): pulses.append(duration))
 controller.fight.update_zones(fish)
 controller.tension = controller.red_start - 0.01
 controller._update_tension_haptics(1.0)
 expect(pulses.is_empty(), "no vibration below this fish's red threshold")
 controller.tension += 0.02
 controller._update_tension_haptics(0.01)
 expect(pulses.size() == 1 and pulses[0] == 80, "entering the red zone requests a short 80ms pulse")
 for tick in 10:
  controller._update_tension_haptics(0.01)
 expect(pulses.size() == 1, "red zone does not vibrate every physics frame")
 controller._update_tension_haptics(0.45)
 expect(pulses.size() == 2, "sustained red tension repeats at the configured interval")
 controller.tension = 0.2
 controller._update_tension_haptics(1.0)
 expect(pulses.size() == 2, "paying out below red stops further pulses")
 controller.tension = 1.0
 controller.haptics_enabled = false
 controller._update_tension_haptics(1.0)
 expect(pulses.size() == 2, "disabled haptics suppress warning vibration")
 controller.haptics_enabled = true
 controller._change_state(controller.State.RESULT)
 controller._update_tension_haptics(1.0)
 expect(pulses.size() == 2, "catch result does not request battle vibration")
 controller.free()
 print("TENSION HAPTICS RESULT: ", errors, " failures")
 quit(errors)
