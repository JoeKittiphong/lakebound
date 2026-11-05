extends SceneTree
class FakeOnline extends "res://features/social/ranking_online.gd":
 var sent: Array = []
 func _send(body: String) -> Error:
  sent.append(JSON.parse_string(body))
  return OK

var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 failures += int(not ok)
 print("PASS: " if ok else "FAIL: ",label)
func settle() -> void:
 for i in 3: await process_frame
func record(id: String, weight: float, map_id: String = "river") -> Dictionary:
 return {"catch_id":id,"species":"tilapia","name":"ปลานิล","map":map_id,"weight":weight,"time":1000.0,"mission_eligible":false}
func reply(service: Node, map_id: String, grams: int, version: String) -> void:
 var rows: Array = [] if grams == 0 else [[service.profile.data.identity.id,"ทดสอบออนไลน์","tilapia",grams]]
 service._completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"schema":3,"version":version,"rows":rows}).to_utf8_buffer())
func run() -> void:
 var profile := AnglerProfile.new()
 profile.data = profile.defaults()
 profile.data.identity.name = "ทดสอบออนไลน์"
 profile.save_path = "user://background-profile.cfg"
 var service: Node = load("res://features/social/ranking_online.tscn").instantiate()
 service.set_script(FakeOnline)
 root.add_child(service)
 service.enabled = false
 service.endpoint = "https://abcdefghijklmnopqrst.supabase.co/rest/v1/rpc/lakebound_rankings"
 service.publishable_key = "sb_publishable_fixture"
 service.sync.save_path = "user://background-ack.cfg"
 service.sync.cache_path = "user://background-cache.cfg"
 service.bind_profile(profile)
 service.enabled = true
 service.watch_map("river")
 await settle()
 check(service.sent.size()==1 and service.sent[0].payload.keys()==["query"],"map entry fetches public leader without guest credentials")
 reply(service,"river",0,"empty")
 check(service.leader_state("river").loaded and service.leader_state("river").record.is_empty(),"empty live map is an honest empty leaderboard")
 profile.changed.emit()
 await settle()
 check(service.sent.size()==1,"unrelated profile changes make no request")
 check(profile.record_catch(record("first",1.0),false,false),"first catch durably saved")
 await settle()
 check(service.busy and service.sent.size()==2 and service.sent[1].payload.catches.size()==1,"catch automatically uploads while ranking panel is closed")
 profile.record_catch(record("second",2.0),false,false)
 await settle()
 check(service.sent.size()==2 and service.dirty,"catch during upload queues follow-up without parallel request")
 reply(service,"river",1000,"one")
 await settle()
 check(service.sent.size()==3 and service.sent[2].payload.catches[0][2]==2000,"newer best survives acknowledgement of older in-flight catch")
 reply(service,"river",2000,"two")
 check(service.leader_state("river").record.weight==2.0 and not service.leader_state("river").cached,"fresh response updates minimap leader")
 profile.record_catch(record("smaller",0.5),false,false)
 await settle()
 check(service.sent.size()==4 and service.sent[3].payload.keys()==["query"],"even non-record fish checks leader without reuploading scores")
 service._completed(HTTPRequest.RESULT_TIMEOUT,0,PackedStringArray(),PackedByteArray())
 check(service.dirty and not service.get_node("Retry").is_stopped() and service.leader_state("river").cached,"offline response keeps pending work, marks cached leader and schedules retry")
 service.get_node("Retry").stop()
 service.flush()
 service._completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"version":"two","not_modified":true}).to_utf8_buffer())
 check(not service.dirty and not service.leader_state("river").cached,"successful conditional retry restores fresh leader")
 var before: int = service.sent.size()
 profile.record_catch(record("smaller",0.5),false,false)
 await settle()
 check(service.sent.size()==before,"duplicate catch delivery does not upload twice")
 var previous_path: String = profile.save_path
 profile.save_path = "user://missing-folder/cannot-save.cfg"
 check(not profile.record_catch(record("unsaved",5.0),false,false),"failed local save rejected")
 await settle()
 check(service.sent.size()==before,"failed save never emits online catch event")
 profile.save_path = previous_path
 profile.record_catch(record("third",3.0),false,false)
 await settle()
 service.watch_map("lotus_marsh")
 reply(service,"river",3000,"three")
 await settle()
 check(service.sent[-1].payload.query.scope=="lotus_marsh","map switch during upload fetches new map after old response")
 reply(service,"lotus_marsh",0,"marsh-empty")
 check(service.leader_state("lotus_marsh").record.is_empty() and service.leader_state("river").record.weight==3.0,"map leaders remain isolated")
 service.unwatch_map("lotus_marsh")
 check(service.get_node("Refresh").is_stopped(),"leaving map stops periodic reads; uploads remain persistent")
 profile.record_catch(record("retry-after-restart",4.0),false,false)
 await settle()
 service._completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"error":"invalid_credentials"}).to_utf8_buffer())
 check(service.dirty and service.get_node("Retry").is_stopped(),"auth failure retains pending best without retry storm")
 var ack_path: String = service.sync.save_path
 var cache_path: String = service.sync.cache_path
 service.queue_free()
 await settle()
 var reopened: Node = load("res://features/social/ranking_online.tscn").instantiate()
 reopened.set_script(FakeOnline)
 root.add_child(reopened)
 reopened.enabled = false
 reopened.endpoint = "https://abcdefghijklmnopqrst.supabase.co/rest/v1/rpc/lakebound_rankings"
 reopened.publishable_key = "sb_publishable_fixture"
 reopened.sync.save_path = ack_path
 reopened.sync.cache_path = cache_path
 reopened.bind_profile(profile)
 reopened.enabled = true
 await settle()
 check(reopened.sent.size()==1 and reopened.sent[0].payload.catches[0][2]==4000,"restarted service restores unacknowledged best from durable profile")
 var read := RankingSync.new()
 read.more = true
 var read_payload := read.build_read("map","river",100)
 check(read.read_only and not read.more and read_payload.query.limit==100,"foreground read remains independent of background upload batching")
 reopened.queue_free()
 await process_frame
 profile.free()
 print("BACKGROUND RANKING RESULT: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
