extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 failures += int(not ok)
 print("PASS: " if ok else "FAIL: ", label)

func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.data.identity.name = "Test Angler"
 profile.data.journal = [{"catch_id":"one","species":"tilapia","map":"river","name":"Tilapia","weight":1.0,"time":1.0}]
 var panel: Control = load("res://features/social/social_panel.tscn").instantiate()
 panel.supabase_key = "sb_publishable_fixture"
 root.add_child(panel)
 panel.supabase_url = ""
 check(panel.get_node("%Rows").get_child_count() == 0, "hidden panel creates no rows at startup")
 panel.open()
 var rows: Node = panel.get_node("%Rows")
 check(rows.get_child_count() == 1, "opening shows current local best")
 var original_id := rows.get_child(0).get_instance_id()
 panel.close()
 var started := Time.get_ticks_usec()
 for i in 1000: profile.changed.emit()
 var elapsed := Time.get_ticks_usec() - started
 check(rows.get_child_count() == 1 and rows.get_child(0).get_instance_id() == original_id, "1000 hidden updates do not rebuild ranking rows")
 check(not panel.busy and panel.request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED, "hidden profile changes make no request")
 print("HIDDEN RANKING UPDATES: 1000 in ",elapsed," us; row replacements=0")
 profile.data.history.map_bests["river:tilapia"].weight = 2.0
 panel.open()
 check("2.000" in panel.get_node("%Personal").text, "reopening reflects updates made while hidden")
 panel._set_busy(true)
 panel._selection_changed()
 check(not panel.busy and not panel.get_node("%Save").disabled and panel.get_node("%Name").editable, "selection cancellation restores input controls")
 panel.supabase_url = "https://obsolete.example.com"
 panel._sync()
 check(not panel.busy and panel.request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED, "retired custom API receives no credentials")
 # Exercise opening with an existing cached board, not just a forced busy flag.
 profile.data = profile.defaults()
 profile.data.identity.name = "Comparison QA"
 panel.supabase_url = "https://abcdefghijklmnopqrst.supabase.co/rest/v1/rpc/lakebound_rankings"
 panel.ranking_sync.configure(panel.supabase_url, str(profile.data.identity.id))
 panel.ranking_sync.views["all:10"] = {"version":"qa", "rows":[{"player_id":"qa", "player_name":"Cached angler", "species":"tilapia", "name":"Tilapia", "map":"river", "weight":1.0}]}
 panel.open()
 check(panel.busy and panel.displaying_cached and panel.get_node("%Comparing").visible and not panel.get_node("%Scroll").visible, "opening cached board still shows comparison until fresh response")
 # Cancel the transport immediately; drive completion deterministically without network.
 panel.request.cancel_request()
 paused = true
 var bar: Control = panel.get_node("%ComparisonMarks/First")
 var previous := bar.scale.y
 await create_timer(0.15).timeout
 check(bar.scale.y != previous, "comparison animation runs while game is paused")
 paused = false
 panel._received(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
 check(panel.get_node("%Comparing").visible and not panel.get_node("SyncRetry").is_stopped(), "comparison stays visible between retries even with cache")
 panel.get_node("SyncRetry").stop()
 panel.retry_attempt = 3
 panel._received(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
 check(not panel.get_node("%Comparing").visible and panel.get_node("%Scroll").visible, "retry exhaustion restores cached board instead of endless animation")
 panel.close()
 check(not panel.busy and not panel.get_node("%Comparing").visible, "closing cancels comparison")
 panel.queue_free()
 await process_frame
 print("SOCIAL LIFECYCLE RESULT: ",failures," failures")
 quit(1 if failures else 0)
