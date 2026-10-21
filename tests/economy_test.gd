extends SceneTree

var checks := 0
var failures := 0
var actions: Array[StringName] = []

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: ", message)

func run() -> void:
 var profile := AnglerProfile.new()
 profile.save_path = "user://economy-test-%d.cfg" % Time.get_ticks_usec()
 root.add_child(profile)
 expect(profile.data.coins == 350 and profile.data.diamonds == 0, "new account starts with coins and no paid currency")
 expect(profile.buy("frog") and profile.equip("frog"), "buy and equip reusable lure")
 expect(profile.prepare_cast() and profile.quantity("frog") == 1, "casting reusable lure does not consume it")
 expect(profile.break_line(20.0, "frog"), "line break persists a pending lure loss")
 var pending: String = profile.data.pending.id
 expect(profile.data.line_remaining == 45.0 and profile.quantity("frog") == 0, "break removes deployed line and one lure")
 expect(not profile.prepare_cast() and not profile.break_line(20.0, "frog"), "pending recovery cannot be overwritten by casting or repeated breaks")
 expect(not profile.recover_with_diamonds() and profile.data.diamonds == 0, "insufficient diamonds never yield a free recovery")
 var reloaded := AnglerProfile.new()
 reloaded.save_path = profile.save_path
 root.add_child(reloaded)
 expect(reloaded.data.pending.id == pending and reloaded.data.line_remaining == 45.0, "pending recovery and reduced line survive restart")
 expect(not profile.apply_verified_reward("reward-1", "wrong-event"), "reward must match the active recovery")
 expect(profile.apply_verified_reward("reward-1", pending), "verified earned ad restores the matching lure")
 expect(not profile.apply_verified_reward("reward-1", pending), "duplicate earned callback cannot grant a second lure")
 expect(profile.quantity("frog") == 1 and profile.data.line_remaining == 45.0, "recovery restores neither line nor fish")
 expect(profile.apply_verified_purchase("purchase-1", 10), "verified purchase credits diamonds")
 expect(not profile.apply_verified_purchase("purchase-1", 10), "purchase replay cannot mint diamonds")
 expect(profile.break_line(5.0, "frog") and profile.recover_with_diamonds(), "diamond recovery completes atomically")
 expect(profile.data.diamonds == 7 and profile.quantity("frog") == 1 and profile.data.line_remaining == 40.0, "diamond cost and line loss are exact")
 expect(profile.equip("worm") and profile.prepare_cast() and profile.quantity("worm") == 19, "natural bait consumes one unit on cast")
 var catch_data := {"species": "tilapia", "name": "ปลานิล", "weight": 2.0, "map": "river", "depth": 1.5, "bait": "worm", "rod": "light", "reel": "basic", "line": "nylon", "time": 1.0}
 expect(profile.keep_catch(catch_data), "caught fish goes into weight-limited storage")
 var huge := catch_data.duplicate()
 huge.weight = 30.0
 expect(not profile.keep_catch(huge), "overweight catch cannot overflow the box")
 var coins: int = profile.data.coins
 expect(profile.sell_catches() and profile.data.coins == coins + 70 and profile.data.catches.is_empty(), "sale credits exact weight value and empties storage")
 expect(not profile.sell_catches() and profile.data.coins == coins + 70, "same stored fish cannot be sold twice")
 expect(profile.record_catch(catch_data, true) and profile.data.boss_history.size() == 1, "journal and boss history persist actual catch context")
 expect(profile.buy("braid") and profile.equip("braid") and profile.data.line_remaining == 80.0, "replacement line consumes a spare and restores its configured length")
 expect(not profile.equip("braid"), "one spare cannot be installed twice")
 var gateway := CommerceGateway.new()
 root.add_child(gateway)
 expect(not gateway.ad_available() and not gateway.request_recovery("x") and not gateway.request_purchase("x"), "unconfigured commerce fails closed without fabricated ads or purchases")
 profile.save_path = "user://missing-directory/profile.cfg"
 var before := profile.data.duplicate(true)
 expect(not profile.buy("worm") and profile.data == before, "save failure rolls back the complete purchase")
 profile.data = profile.defaults()
 profile.data.coins = 0
 profile.data.stock.worm = 0
 profile.data.stock.dough = 0
 profile.data.line_remaining = 0.0
 profile.save_path = reloaded.save_path
 expect(profile.emergency_supplies() and profile.quantity("worm") == 3 and profile.data.line_remaining == 15.0, "broke player can continue without ads or payment")
 expect(not profile.emergency_supplies(), "emergency supply cannot be farmed repeatedly")
 var malformed := profile.data.duplicate(true)
 malformed.pending = {"lure": "worm", "id": "invalid", "cost": 0}
 expect(not profile._valid(malformed), "malformed saved recovery is rejected before use")
 malformed = profile.data.duplicate(true)
 malformed.line_remaining = INF
 expect(not profile._valid(malformed), "nonfinite saved line cannot enter simulation")
 var protected_path := profile.save_path
 var config := ConfigFile.new()
 config.set_value("meta", "version", 99)
 config.save(protected_path)
 reloaded.save_path = protected_path
 reloaded.load_profile()
 expect(reloaded.incompatible and not reloaded.buy("worm"), "future-version player data is preserved and blocks overwrites")
 var preserved := ConfigFile.new()
 preserved.load(protected_path)
 expect(preserved.get_value("meta", "version") == 99, "failed transaction never overwrites an incompatible save")
 test_lure_input()
 test_population()
 reloaded.free()
 gateway.free()
 profile.free()
 print("ECONOMY RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)

func test_lure_input() -> void:
 var input := LureInput.new()
 input.action.connect(func(action: StringName): actions.append(action))
 input.press()
 input.advance(0.05)
 input.release()
 input.advance(0.23)
 expect(actions == [&"tap"], "single tap emits once after double-tap window")
 actions.clear()
 input.press()
 input.release()
 input.advance(0.1)
 input.press()
 input.release()
 input.advance(0.3)
 expect(actions == [&"double_tap"], "double tap suppresses two single taps")
 actions.clear()
 input.press()
 input.advance(0.4)
 input.advance(0.4)
 input.release()
 expect(actions == [&"hold", &"release"], "hold and release emit once each, without accidental taps")
 actions.clear()
 input.press()
 input.reset()
 input.release()
 input.advance(1.0)
 expect(actions.is_empty(), "focus/reset cancels pending input without generating an action")

func test_population() -> void:
 var pond := PondEcosystem.new()
 root.add_child(pond)
 pond.set_physics_process(false)
 var boss := pond.boss()
 expect(boss in pond.fish, "boss is a real existing population member")
 var old_weight: float = boss.weight
 var snapshot := pond.snapshot()
 expect(pond.restore(snapshot) and pond.fish.size() == snapshot.size() and pond.boss().weight == old_weight, "population snapshot restores identities, weights and actual boss")
 boss = pond.boss()
 pond.keep(boss)
 expect(pond.boss() != boss and pond.boss().weight <= old_weight, "catching and keeping boss selects next largest remaining fish")
 var invalid := snapshot.duplicate(true)
 invalid[0].weight = NAN
 expect(not pond.restore(invalid), "invalid population does not replace live fish")
 pond.free()
