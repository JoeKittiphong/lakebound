extends SceneTree
var checks:=0
var failures:=0
var output:=OS.get_environment("LAKEBOUND_QA_DIR")
var profile: AnglerProfile
var game: Node3D
var measurements: Dictionary={}
func _initialize() -> void:call_deferred("run")
func expect(value: bool,label: String) -> void:
 checks+=1
 if not value:failures+=1
 print("PASS: " if value else "FAIL: ",label)
func open_game(economy: bool=true) -> PondEcosystem:
 game=load("res://features/regions/grand_river.tscn").instantiate();game.economy_enabled=economy
 root.add_child(game);current_scene=game
 game.get_node("FishingEffects").audio_enabled=false
 return game.get_node("PondEcosystem")
func close_game() -> void:
 game.queue_free();await process_frame;await process_frame
func old_profile(records: Array) -> void:
 profile.data=profile.defaults();profile.incompatible=false;profile.save_error=""
 profile.data.coins=777;profile.data.stock.worm=37;profile.data.line_remaining=32.0
 profile.data.ponds["river"]=records
func cave_count(pond: PondEcosystem) -> int:
 var count:=0
 for fish in pond.fish:
  if pond.definition.in_cave_area(Vector2(fish.position.x,fish.position.z)):count+=1
 return count
func run() -> void:
 if output.is_empty():output=ProjectSettings.globalize_path("res://../exports/rainforest-lake/fish-qa")
 DirAccess.make_dir_recursive_absolute(output)
 root.get_node("FishCollection").recording_enabled=false
 profile=root.get_node("AnglerSave");profile.save_path=output.path_join("population-profile.cfg");profile.data=profile.defaults()
 var pond:=open_game(false)
 expect(pond.population_limit==960 and pond.fish.size()==960,"960 residents exist before any cast")
 expect(pond.species.size()==48,"48 authored fish species in lake scene")
 expect(RegionCatalog.find("river").fish_count==48,"menu advertises the expanded roster")
 var membership=load("res://features/collection/collection_progress.gd")
 expect(membership.species_for("river").size()==48,"collection includes all 48 lake species")
 var species_ids:={};var live_ids:={};var models_valid:=true;var habitat_valid:=true;var occupied:={};var groups:={}
 for species in pond.species:
  species_ids[species.id]=0
  models_valid=models_valid and species.model_scene!=null and species.collection_icon!=null and FishCatalog.find(species.id)!=null
 expect(species_ids.size()==48,"roster contains no alias or duplicate species IDs")
 expect(models_valid,"all species have models, icons and catalogue entries")
 for fish in pond.fish:
  species_ids[fish.species.id]+=1;live_ids[fish.persistent_key]=true
  var p:=Vector2(fish.position.x,fish.position.z);var depth:=pond.definition.water_depth_at(p)
  habitat_valid=habitat_valid and fish.position.is_finite() and fish.position.y>=fish.species.preferred_depth.x-.01 and fish.position.y<=fish.species.preferred_depth.y+.01 and fish.position.y<depth
  occupied[Vector2i(floori((p.x+500)/50),floori((p.y+250)/50))]=true
  var group: int=pond.definition.habitat_group(Vector3(p.x,depth,p.y));groups[group]=int(groups.get(group,0))+1
 expect(live_ids.size()==960,"all residents have unique persistent identities")
 expect(habitat_valid,"all initial fish fit water and preferred vertical depth")
 var balanced:=true
 for count in species_ids.values():balanced=balanced and count==20
 expect(balanced,"new lake starts with twenty fish per species")
 expect(occupied.size()>=100,"population spreads across at least 100 world cells")
 for group in range(6):expect(int(groups.get(group,0))>=20,"populated habitat group "+str(group))
 expect(pond.definition.fish_habitats.size()>400,"saved editable habitat anchors cover the large lake")
 var effects=game.get_node("FishingEffects")
 expect(effects.visual_pool.size()==12,"rendered fish pool remains capped at twelve models")
 game.get_node("Player").set_physics_process(false)
 game.get_node("Player").global_position=Vector3(14,.3,-215)
 effects._update_fish_visuals()
 var visible:=0
 for visual in effects.visual_pool:
  if visual.visible:visible+=1
 expect(visible>=8 and visible<=12,"dense cave renders more fish without exceeding model budget")
 pond.set_physics_process(false)
 game.get_node("Player").global_position=Vector3(-324,2,143)
 var distant: RefCounted
 for fish in pond.fish:
  if Vector2(fish.position.x+324,fish.position.z-143).length()>200:distant=fish;break
 var before_caution: float=distant.caution;distant.caution=.8;distant.simulation_elapsed=0
 pond.step(.15)
 expect(is_equal_approx(distant.caution,.8) and distant.simulation_elapsed>.1,"far fish accumulate time instead of full-rate updates")
 pond.set_bait(distant.position,&"worm")
 pond.step(.15)
 expect(distant.caution<.8,"fish near a distant cast immediately resume full simulation")
 pond.cancel_bait();distant.caution=before_caution
 var started:=Time.get_ticks_usec()
 for i in 100:pond.step(.15)
 measurements={"mean_simulation_step_ms":(Time.get_ticks_usec()-started)/100000.0,"occupied_cells":occupied.size(),"habitat_groups":groups,"rendered_models":visible}
 print("POPULATION_MEASUREMENTS ",JSON.stringify(measurements))
 await close_game()
 var legacy:=PondEcosystem.new();legacy.population_limit=112;legacy.definition=load("res://world/river/river_definition.tres");root.add_child(legacy)
 var original:=legacy.snapshot();var identities:={}
 for fish in original:identities[fish.persistent_key]=fish.weight
 legacy.queue_free();await process_frame
 old_profile(original);pond=open_game()
 expect(pond.fish.size()==960,"112-fish legacy lake receives 848 additions")
 var intact:=true;var retained:=0
 for fish in pond.fish:
  if identities.has(fish.persistent_key):retained+=1;intact=intact and fish.weight==identities[fish.persistent_key]
 expect(intact and retained==112,"every original fish identity and weight is retained")
 expect(profile.data.coins==777 and profile.data.stock.worm==37 and profile.data.line_remaining==32.0,"expansion preserves wallet, bait and line")
 expect(profile.data.pond_revisions.get("river")=="rainforest_960_v1","expansion revision is saved atomically with fish")
 await close_game();profile.load_profile();pond=open_game()
 expect(pond.fish.size()==960,"reload does not apply expansion twice")
 pond.keep(pond.fish[0]);expect(profile.store_pond("river",pond.snapshot()),"successful keep commits its reduced population");await close_game();profile.load_profile();pond=open_game()
 expect(pond.fish.size()==959,"keeping fish is not undone on reload")
 await close_game();profile.store_pond("river",[]);profile.load_profile();pond=open_game()
 expect(pond.fish.is_empty(),"empty expanded lake does not trigger another migration")
 await close_game();old_profile(original.slice(0,40));pond=open_game()
 expect(pond.fish.size()==888,"depleted legacy lake gets only 848 new fish, not a reset to 960")
 await close_game();profile.load_profile();pond=open_game()
 expect(pond.fish.size()==888,"depleted population stays depleted after reload")
 await close_game()
 old_profile(original.slice(0,40));var good_path:=profile.save_path;profile.save_path=output.path_join("missing-parent/no-directory/profile.cfg")
 pond=open_game()
 expect(pond.fish.size()==40 and profile.data.ponds.river.size()==40 and not profile.data.pond_revisions.has("river"),"failed expansion save rolls back both live and saved population")
 await close_game();profile.save_path=good_path
 var old_schema:=profile.defaults();old_schema.erase("pond_revisions")
 var old_path:=output.path_join("pre-expansion-schema.cfg");ProfileStore.save_profile(old_path,old_schema)
 var migrated:=ProfileStore.load_profile(old_path)
 expect(not migrated.incompatible and migrated.data.pond_revisions.is_empty(),"old profile schema loads without resetting progress")
 FileAccess.open(output.path_join("population-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"  "))
 print("POPULATION_RESULT ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
