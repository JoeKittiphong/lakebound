extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1;failures+=int(not ok)
 print("PASS: " if ok else "FAIL: ",label)
func caught(index: int) -> Dictionary:
 return {"catch_id":"%032x"%(index+1),"species":"tilapia","map":"river","weight":float(index+100)/1000,"time":1700000000.123+index,"name":"ปลานิล","depth":1.5,"bait_id":"worm","bait":"หนอน","rod":"คันเบา","reel":"รอกพื้นฐาน","line":"ไนลอน","fish_key":"river:fish-%d"%index,"mission_eligible":false,"location":{"angler_xz":Vector2(-10.25,20.5),"bite_xz":Vector2(-12.5,22.75),"from_boat":false}}
func run() -> void:
 var profile:=AnglerProfile.new()
 profile.data=profile.defaults();profile.data.identity.name="ทดสอบคลาวด์"
 profile.save_path="user://cloud-sync-profile.cfg"
 profile.data.cloud.owner="00000000-0000-4000-8000-000000000001"
 profile.data.cloud.tracking=true
 for index in 200:
  check(profile.record_catch(caught(index),false,false),"durable offline catch %d"%index)
 check(profile.data.journal.size()==10,"game journal remains bounded")
 check(profile.data.cloud.events.size()==201,"all 200 unsent catches survive journal compaction plus one loadout context")
 var reloaded:=ProfileStore.load_profile(profile.save_path)
 check(not reloaded.incompatible and reloaded.data.cloud.events.size()==201,"crash/restart restores durable outbox from the same atomic save")
 var packet:=CloudOutbox.packet(profile.data.cloud)
 var count: int=packet.p.get("f",[]).size()+packet.p.get("o",[]).size()
 check(count==64 and JSON.stringify(packet).to_utf8_buffer().size()<=16384,"batch is bounded by 64 events and 16 KiB")
 check(not packet.p.has("token") and not packet.p.has("player_id"),"compact request omits guest secret and redundant identity")
 var first: Array=packet.p.f[0]
 check(first[4]+packet.p.t==1700000000123,"integer millisecond timestamp preserves precision")
 check(first[10]==[-1025,2050,-1250,2275,0],"location keeps centimetre precision without repeated field names")
 var before: Dictionary=profile.data.cloud.duplicate(true)
 var forged:=CloudOutbox.accept(before,[2,1,20000],packet)
 check(forged.is_empty(),"forged acknowledgement cannot drop unsent events")
 var partial:=CloudOutbox.accept(before,[2,31,31],packet)
 check(partial.events.size()==170 and partial.events[0][0]==32,"partial contiguous acknowledgement preserves unsent suffix")
 var newest:=caught(201)
 profile.record_catch(newest,false,false)
 var updated:=CloudOutbox.accept(profile.data.cloud,[2,64,64],packet)
 check(updated.events[-1][2][-1]==newest.catch_id,"new catch during flight cannot be acknowledged by older response")
 var old_path: String=profile.save_path
 var old_next: int=profile.data.cloud.next
 profile.save_path="user://missing-cloud-folder/failed.cfg"
 check(not profile.record_catch(caught(999),false,false),"disk failure rejects both catch and outbox atomically")
 check(profile.data.cloud.next==old_next,"disk failure does not consume a sequence or leave a phantom event")
 profile.save_path=old_path
 check(profile.add_fishing_spot("river",Vector2(1,2)),"favorite saved locally")
 var spot_id: String=profile.data.map_memory.favorites[0].id
 check(profile.remove_fishing_spot(spot_id) and profile.data.cloud.events[-1][2]==[12,spot_id],"favorite deletion queues durable tombstone")
 profile.set_catch_note(newest.catch_id,"ปลากินดีมาก")
 check(profile.data.cloud.events[-1][2]==[10,newest.catch_id,"ปลากินดีมาก"],"Thai note sends only changed item")
 check(profile.buy("worm") and profile.data.cloud.events[-1][2][0]==2,"buy queues command, never a client balance overwrite")
 check(not profile.grant_trial_equipment(),"online cloud profile cannot mint playtest equipment")
 var clean:=profile.defaults();clean.identity.name="Cloud QA"
 var fish:=CloudCatalog.code("fish","tilapia")
 var worm:=CloudCatalog.code("item","worm")
 var gear: Array=[CloudCatalog.code("item","light_rod"),CloudCatalog.code("item","basic_reel"),CloudCatalog.code("item","nylon"),CloudCatalog.code("rig","float")]
 var wire: Array=["a".repeat(32),CloudCatalog.code("map","river"),fish,1250,1700000000123,150,worm,gear,"fish-restore",0,[-1025,2050,-1250,2275,0]]
 var rows: Array=[["w","",[350,0]],["h",fish,[1,1250,1250,1250,1250]],["j",wire[0],wire],["k","river:tilapia",wire],["b",wire[0],true],["n","","Cloud QA"]]
 var restored:=CloudRestore.assemble(clean,rows)
 check(not restored.is_empty() and restored.catches[0].catch_id==wire[0],"restore preserves journal/box identity and validates profile")
 check(restored.history.stats.tilapia.count==1 and restored.journal[0].location.angler_xz==Vector2(-10.25,20.5),"restore recovers collection and precise map position")
 var empty_spots:=CloudRestore.delta_rows({"s":{}})
 clean.map_memory.favorites=[{"id":"spot","map":"river","position":Vector2.ZERO,"from_boat":false,"name":"จุดเก่า"}]
 var patched:=CloudRestore.assemble(clean,empty_spots,false)
 check(not patched.is_empty() and patched.map_memory.favorites.is_empty(),"empty server domain clears deleted local favorites")
 var corrupt:=rows.duplicate(true);corrupt.append(["h",999999,[1,1,1,1,1]])
 check(CloudRestore.assemble(clean,corrupt).is_empty(),"unknown catalog ID rejects complete restore without replacing save")
 var warm:=CloudOutbox.defaults();warm.tracking=true;warm.contexts[JSON.stringify(gear)]=1;warm.context_next=2
 var b:=profile.defaults();b.cloud=warm;b.identity.name="Cloud QA"
 var a:=b.duplicate(true)
 CloudOutbox.capture(b,a,[1,caught(0)])
 var bytes:=JSON.stringify(CloudOutbox.packet(a.cloud)).to_utf8_buffer().size()
 check(bytes<=250,"actual warm-context catch RPC body stays at or below 250 bytes")
 print("CLOUD PAYLOAD: warm catch body=",bytes," bytes; ack=",JSON.stringify([2,20,41]).to_utf8_buffer().size()," bytes (HTTP/auth excluded)")
 check(PlayerSavePaths.ACCOUNTS=="accounts_cloud_v2" and profile.save_path=="user://cloud-sync-profile.cfg","new production save generation is separate from legacy data")
 profile.free()
 print("CLOUD SYNC RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
