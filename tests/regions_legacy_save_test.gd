extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 print("PASS: " if ok else "FAIL: ",label)
 if not ok:errors+=1
func run() -> void:
 root.get_node("FishCollection").recording_enabled=false
 var profile: AnglerProfile=root.get_node("AnglerSave");profile.save_path="res://exports/qa-fish-models/legacy_region_profile.cfg";profile.data=profile.defaults();profile.incompatible=false;profile.save_error=""
 var legacy:=PondEcosystem.new();legacy.definition=load("res://world/river/river_definition.tres");legacy.population_limit=112;root.add_child(legacy)
 var original:=legacy.snapshot();var identities:={}
 for fish in original:identities[fish.persistent_key]=fish.weight
 profile.data.ponds.river=original;profile.data.coins=777;profile.data.stock.worm=37;profile.data.line_remaining=32.0
 profile.data.missions.started=true;profile.data.missions.tracked="first_three"
 profile.data.missions.entries.first_three={"revision":1,"progress":2.0,"claimed":false,"seen":["old-one","old-two"],"unique":[]}
 legacy.queue_free();await process_frame
 var game: Node3D=load("res://features/regions/grand_river.tscn").instantiate();game.economy_enabled=true;root.add_child(game);current_scene=game
 for i in 5:await physics_frame
 check(not profile.incompatible,"old river profile remains compatible")
 check(profile.data.coins==777 and profile.data.stock.worm==37 and profile.data.line_remaining==32.0,"wallet, bait stock and line length preserved")
 var pond: PondEcosystem=game.get_node("PondEcosystem")
 check(pond.species.size()==28 and pond.fish.size()==112,"expanded roster retains existing population")
 var intact:=true
 for fish in pond.fish:
  if not identities.has(fish.persistent_key) or identities[fish.persistent_key]!=fish.weight:intact=false
 check(intact,"every old fish identity and weight preserved")
 check(MissionProgress.entry(profile.data.missions,MissionCatalog.find("first_three")).progress==2.0,"existing mission progress preserved")
 check(game.get_node("HUD/FishingHUD/MissionPanel").definitions.size()==12,"all twelve original missions remain available")
 check(profile.data.missions.tracked=="first_three","tracked original mission preserved")
 game.queue_free();await process_frame
 print("LEGACY REGION RESULT: 7 checks, ",errors," failures")
 quit(int(errors>0))
