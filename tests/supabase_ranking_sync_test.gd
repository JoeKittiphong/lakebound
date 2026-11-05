extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
 checks += 1
 if not ok: failures += 1
 print("PASS: " if ok else "FAIL: ",message)
func run() -> void:
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.save_path="user://sheets-frequency-profile.cfg"
 profile.data=profile.defaults()
 profile.data.identity.name="ทดสอบชีต"
 var record: Dictionary={"catch_id":"local-first","species":"tilapia","name":"ปลานิล","map":"river","weight":1.0,"time":1000.0,"depth":1.0,"bait":"worm","rod":"rod","reel":"reel","line":"line","mission_eligible":false}
 var url: String="https://abcdefghijklmnopqrst.supabase.co/rest/v1/rpc/lakebound_rankings"
 var viewer:=RankingSync.new()
 viewer.save_path="user://score-free-viewer.cfg"
 viewer.cache_path="user://score-free-views.cfg"
 viewer.configure(url,str(profile.data.identity.id))
 var read_payload := viewer.build(profile,"all","",10)
 expect(viewer.read_only,"first score-free board skips guest registration")
 var read_body: Dictionary = JSON.parse_string(viewer.rpc_body(read_payload))
 expect(read_body.payload.keys() == ["query"],"public RPC body omits guest ID, token, catches and name")
 viewer.accept({"schema":3,"version":"empty-view","rows":[]})
 expect(viewer.acknowledged_name.is_empty(),"public RPC never acknowledges an unregistered name")
 expect(SupabaseConnectionSettings.valid_url(url),"accept exact Supabase RPC endpoint")
 expect(not SupabaseConnectionSettings.valid_url(url+"?token=private") and not SupabaseConnectionSettings.valid_url("https://script.google.com/evil"),"reject token query strings and unrelated paths")
 var panel: Control=load("res://features/social/social_panel.tscn").instantiate()
 panel.supabase_key = "sb_publishable_fixture"
 root.add_child(panel)
 panel.supabase_url=url
 panel.hide()
 expect(profile.record_catch(record,false,false),"catch saves locally")
 await process_frame
 expect(not panel.busy and panel.request.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED,"catch does not start a foreground-panel request")
 var sync:=RankingSync.new()
 sync.save_path="user://sheets-ack-test.cfg"
 sync.cache_path="user://sheets-views-test.cfg"
 sync.configure(url,str(profile.data.identity.id))
 var body:=sync.build(profile,"map","river",10)
 expect(body.catches.size()==1 and body.catches[0].size()==5 and not body.catches[0].has("ปลานิล"),"board builds one minimal new-score tuple")
 expect(body.query.scope=="river" and body.query.limit==10,"one request asks for selected-map ranking after comparison")
 expect(sync.accept({"error":"busy_retry"}).is_empty() and sync.build(profile,"map","river",10).catches.size()==1,"failed upload is retained for retry")
 var response: Dictionary={"schema":3,"version":"one","rows":[[profile.data.identity.id,"ทดสอบชีต","tilapia",1000]]}
 var decoded:=sync.accept(response)
 expect(decoded.rows[0].name=="ปลานิล" and decoded.rows[0].map=="river" and decoded.rows[0].weight==1.0,"minimal ranking resolves local catalog names")
 body=sync.build(profile,"map","river",10)
 expect(body.catches.is_empty() and not body.has("player_name") and body.query.version=="one","second board request sends neither acknowledged catches nor unchanged name")
 expect(sync.read_only,"unchanged board uses GET and bypasses the write queue")
 expect(sync.accept({"version":"one","not_modified":true}).rows.size()==1,"unchanged ranking reuses matching cached rows")
 var reopened:=RankingSync.new()
 reopened.save_path=sync.save_path
 reopened.cache_path=sync.cache_path
 reopened.configure(url,str(profile.data.identity.id))
 expect(reopened.build(profile,"all","",10).catches.is_empty(),"acknowledgements survive app restart")
 var cache_start:=Time.get_ticks_usec()
 var persisted:=reopened.cached_view("map","river",10)
 var cache_ms:=float(Time.get_ticks_usec()-cache_start)/1000.0
 expect(not persisted.is_empty() and persisted.rows[0].weight==1.0,"ranking cache survives restart independently of network")
 expect(cache_ms<1000.0,"cached ranking lookup is below one second")
 print("CACHED VIEW LOOKUP: %.3f ms"%cache_ms)
 var newer:=record.duplicate()
 newer.catch_id="local-new"
 newer.weight=2.0
 profile.record_catch(newer,false,false)
 body=sync.build(profile,"map","river",10)
 expect(body.catches.size()==1,"new record waits locally until board request")
 var newest:=record.duplicate()
 newest.catch_id="local-newest"
 newest.weight=3.0
 profile.record_catch(newest,false,false)
 sync.accept({"schema":3,"version":"two","rows":[[profile.data.identity.id,"ทดสอบชีต","tilapia",2000]]})
 expect(sync.build(profile,"map","river",10).catches[0][2]==3000,"catch made during a request stays pending after old response")
 sync.configure("https://zyxwvutsrqponmlkjihg.supabase.co/rest/v1/rpc/lakebound_rankings",str(profile.data.identity.id))
 expect(sync.build(profile,"map","river",10).catches.size()==1,"new endpoint requires fresh upload acknowledgements")
 panel.show()
 panel._received(HTTPRequest.RESULT_SUCCESS,503,PackedStringArray(),JSON.stringify({"error":"busy_retry"}).to_utf8_buffer())
 expect(not panel.get_node("SyncRetry").is_stopped() and panel.retry_attempt==1,"busy service schedules a jittered retry instead of a request storm")
 panel.close()
 expect(panel.get_node("SyncRetry").is_stopped(),"closing ranking cancels pending network retries")
 panel.show()
 panel.retry_attempt=3
 panel._received(HTTPRequest.RESULT_SUCCESS,503,PackedStringArray(),JSON.stringify({"error":"busy_retry"}).to_utf8_buffer())
 expect(panel.get_node("SyncRetry").is_stopped(),"retries stop after three attempts")
 panel.hide()
 panel.ranking_sync.configure(url,str(profile.data.identity.id))
 panel.ranking_sync.save_path="user://closed-batch-ack.cfg"
 panel.ranking_sync.more=true
 panel.ranking_sync.pending={"river:tilapia":"batch-signature"}
 panel.ranking_sync.pending_name=profile.data.identity.name
 panel._received(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"ok":true}).to_utf8_buffer())
 expect(not panel.busy and panel.request.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED,"closed board acknowledges completed batch without sending the next batch")
 panel.queue_free()
 print("SUPABASE RANKING SYNC RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
