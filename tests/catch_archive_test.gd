extends SceneTree

var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures += 1
 print("PASS: " if ok else "FAIL: ", message)
func record(index: int, species: String = "tilapia") -> Dictionary:
 return {"catch_id": "archive-%s-%d" % [species,index], "species": species, "name": "ปลานิล" if species == "tilapia" else "ปลาดุก", "weight": float(index+1)/1000.0,
  "map": "coral_coast" if index < 10 else "river", "time": 1000.0+index,
  "bait":"ไส้เดือน", "rod":"คัน", "reel":"รอก", "line":"สาย", "depth":1.0, "mission_eligible":false}

func run() -> void:
 var profile := AnglerProfile.new()
 profile.save_path = "user://archive-profile.cfg"
 var legacy := profile.defaults()
 legacy.erase("history")
 legacy.coins = 999
 for i in 1000:
  var r := record(i)
  legacy.journal.append(r)
  if i%10 == 0: legacy.boss_history.append(r)
 for i in 50: legacy.journal.append(record(i,"catfish"))
 var cfg := ConfigFile.new()
 cfg.set_value("meta","version",1)
 cfg.set_value("profile","data",legacy)
 expect(cfg.save(profile.save_path)==OK,"write legacy 1050-catch fixture")
 var original_bytes := FileAccess.get_file_as_bytes(profile.save_path).size()
 profile.load_profile()
 expect(not profile.incompatible and profile.data.journal.size()==20,"migrate to ten largest records per species")
 var ids := {}
 for r in profile.data.journal:
  ids[r.species] = int(ids.get(r.species,0))+1
  expect(r.weight>=0.991 if r.species=="tilapia" else r.weight>=0.041,"retained record belongs to largest ten")
 expect(ids.tilapia==10 and ids.catfish==10,"independent species limits")
 expect(profile.lifetime_catches()==1050 and profile.data.coins==999,"migration retains all-time counts and currency")
 expect(profile.data.history.boss_counts.river==99 and profile.data.history.boss_counts.coral_coast==1,"boss victory counters survive history pruning")
 var winners := AnglerIdentity.best(profile.ranking_records(),"map","coral_coast")
 expect(not winners.is_empty() and is_equal_approx(winners[0].weight,0.010),"map best survives outside global top ten")
 var collection: Node = load("res://features/collection/fish_collection.gd").new()
 collection.save_path = "user://archive-collection.cfg"
 collection.records = {"tilapia":{"count":1200,"total":1000.0,"best":1.0,"smallest":0.001,"last":1.0},"catfish":{"count":50,"total":1.275,"best":0.05,"smallest":0.001,"last":0.05}}
 expect(collection.save_records(),"persist older collection with more catches than journal")
 expect(CatchSettlement.reconcile(profile,collection),"reconcile legacy history and collection")
 expect(profile.lifetime_catches()==1250 and collection.stats(&"tilapia").count==1200,"preserve higher legacy collection totals without double counting")
 var compact_bytes := FileAccess.get_file_as_bytes(profile.save_path).size()
 expect(compact_bytes < original_bytes/3,"compacted save is less than one third of original")
 print("ARCHIVE SIZE: %d -> %d bytes"%[original_bytes,compact_bytes])
 expect(profile.data.history.pending.is_empty() and collection._catch_events.size()<=512,"clear recovery queue and bound applied-event ledger")
 var small := record(10001)
 small.weight=0.0005
 expect(CatchSettlement.persist(profile,collection,small).saved,"small catch still settles")
 expect(profile.lifetime_catches()==1251 and profile.data.journal.size()==20,"small catch increments totals without increasing retained history")
 expect(CatchSettlement.persist(profile,collection,small).saved and profile.lifetime_catches()==1251,"discarded small record can retry without recounting")
 collection.save_path="user://archive-missing-folder/collection.cfg"
 var interrupted := record(10002)
 interrupted.weight=0.0004
 expect(not CatchSettlement.persist(profile,collection,interrupted).saved,"failed collection write leaves replayable small catch")
 expect(profile.data.history.pending.size()==1 and not FishingJournal.has_catch(profile.data.journal,interrupted.catch_id),"pending recovery is independent of top ten")
 collection.free()
 collection=load("res://features/collection/fish_collection.gd").new()
 collection.save_path="user://archive-collection.cfg"
 collection.load_records()
 profile.load_profile()
 expect(CatchSettlement.reconcile(profile,collection) and collection.stats(&"tilapia").count==1202,"restart replays the discarded small catch exactly once")
 profile.load_profile()
 expect(profile.lifetime_catches()==1252 and profile.data.history.pending.is_empty(),"all-time totals and compact history survive reload")
 var missing: Node=load("res://features/collection/fish_collection.gd").new()
 missing.save_path="user://archive-rebuilt-collection.cfg"
 missing.load_records()
 expect(CatchSettlement.reconcile(profile,missing) and missing.stats(&"tilapia").count==1202,"missing collection restores complete totals from bounded archive")
 var before:=profile.data.duplicate(true)
 profile.save_path="user://archive-missing-folder/profile.cfg"
 expect(not profile.record_catch(record(11000),true) and profile.data==before,"failed profile write rolls back summaries, top ten and recovery state")
 profile.free()
 collection.free()
 missing.free()
 print("CATCH ARCHIVE RESULT: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
