extends SceneTree
## Run against an exported pack with --main-pack; source-only checks miss export conversion bugs.
func _initialize() -> void:
 var rod := TackleCatalog.item("light_rod") as TackleItem
 var reel := TackleCatalog.item("basic_reel") as TackleItem
 var bait := TackleCatalog.item("worm") as TackleItem
 var line := TackleCatalog.item("nylon") as TackleItem
 var rig := bait.terminal_rigs[0]
 var result := RigCompatibility.evaluate(rod, reel, line, bait, rig)
 var passed: bool = result.allowed and "cast_float" in rod.rod_spec.techniques and "cast_float" in reel.reel_spec.techniques
 print("PACKED STARTER RESULT: ", "PASS" if passed else "FAIL", " rod=", rod.rod_spec.techniques, " reel=", reel.reel_spec.techniques, " result=", result)
 quit(0 if passed else 1)
