extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 failures += int(not ok)
 print("PASS: " if ok else "FAIL: ", label)

func run() -> void:
 var id := "a".repeat(32)
 var row: Array = [id, "Angler", "river", "tilapia", 1000]
 check(RankingSnapshot.decode([row], "all", 10).rows[0].weight == 1.0, "compact grams decode")
 check(RankingSnapshot.decode([], "all", 10).has("rows"), "empty board is valid")
 for invalid in [null, {}, "rows", [null], [[id, "Angler"]]]:
  check(RankingSnapshot.decode(invalid, "all", 10).is_empty(), "reject malformed wire")
 for field in range(5):
  var broken := row.duplicate()
  broken[field] = null
  check(RankingSnapshot.decode([broken], "all", 10).is_empty(), "reject null field %d" % field)
 for grams in [-1, 0, 0.5, NAN, INF, true, "1000", 1000000001]:
  var broken := row.duplicate()
  broken[4] = grams
  check(RankingSnapshot.decode([broken], "all", 10).is_empty(), "reject invalid grams")
 for change in [[0,"z".repeat(32)], [1,"=bad\nname"], [2,"unknown"], [3,"unknown"]]:
  var broken := row.duplicate()
  broken[change[0]] = change[1]
  check(RankingSnapshot.decode([broken], "all", 10).is_empty(), "reject invalid row identity/catalog")
 check(RankingSnapshot.decode([row,row], "all", 10).is_empty(), "duplicate players rejected")
 var bigger := row.duplicate()
 bigger[0] = "b".repeat(32)
 bigger[4] = 2000
 check(RankingSnapshot.decode([row,bigger], "all", 10).is_empty(), "out-of-order ranking rejected")
 check(RankingSnapshot.decode([row], "all", 11).is_empty(), "unsupported limit rejected")
 check(not RankingSnapshot.valid_version(123) and not RankingSnapshot.valid_version(""), "invalid cache versions rejected")

 var sync := RankingSync.new()
 sync.save_path = "user://snapshot-ack.cfg"
 sync.cache_path = "user://snapshot-views.cfg"
 sync.configure("https://abcdefghijklmnopqrst.supabase.co/rest/v1/rpc/lakebound_rankings",id)
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.data.identity.id = id
 profile.data.identity.name = "Angler"
 sync.build(profile,"all","",10)
 check(sync.accept({"schema":3,"version":"good","rows":[row]}).has("rows"), "accept valid snapshot")
 var prior := sync.views.duplicate(true)
 check(sync.accept({"schema":3,"version":"bad","rows":[row,row]}).is_empty() and sync.views == prior, "bad response preserves good cache")
 check(sync.accept({"version":"good","not_modified":"true"}).is_empty(), "conditional flag must be boolean")
 var config := ConfigFile.new()
 config.set_value("cache","endpoint",sync.endpoint)
 config.set_value("cache","player",id)
 config.set_value("cache","views",{"all:10":{"version":"bad","rows":[row,row]}})
 config.save(sync.cache_path)
 var reopened := RankingSync.new()
 reopened.save_path = sync.save_path
 reopened.cache_path = sync.cache_path
 reopened.configure(sync.endpoint,id)
 check(reopened.views.is_empty(), "disk cache uses same row validator")

 var panel: Control = load("res://features/social/social_panel.tscn").instantiate()
 panel.supabase_key = "sb_publishable_fixture"
 root.add_child(panel)
 panel.hide()
 panel.ranking_sync.save_path = "user://http-status-ack.cfg"
 panel.ranking_sync.more = true
 panel.ranking_sync.pending = {"river:tilapia":"unsent"}
 panel._received(HTTPRequest.RESULT_SUCCESS,503,PackedStringArray(),JSON.stringify({"ok":true}).to_utf8_buffer())
 check(panel.ranking_sync.acknowledged.is_empty(), "non-200 cannot acknowledge upload")
 panel._received(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),(" ".repeat(RankingSnapshot.MAX_RESPONSE_BYTES)+JSON.stringify({"ok":true})).to_utf8_buffer())
 check(panel.ranking_sync.acknowledged.is_empty(), "oversized body cannot acknowledge upload")
 check(panel.request.body_size_limit == RankingSnapshot.MAX_RESPONSE_BYTES and panel.request.max_redirects == 0, "authored request limits and redirects disabled")
 panel._received(HTTPRequest.RESULT_SUCCESS,302,PackedStringArray(["Location: https://evil.example/macros/echo?x=1"]),PackedByteArray())
 check(panel.request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED, "untrusted redirect not followed")
 panel.queue_free()
 await process_frame
 print("RANKING SNAPSHOT RESULT: ",failures," failures")
 quit(1 if failures else 0)
