extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 if not ok: failures += 1
 print("PASS: " if ok else "FAIL: ", message)
func wait_request(panel: Control) -> void:
 while panel.busy:
  await panel.request.request_completed
  await process_frame
func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.save_path = "user://sheets-live-profile.cfg"
 profile.data = profile.defaults()
 profile.data.identity.name = "QA Godot HTTP"
 var panel: Control = load("res://features/social/social_panel.tscn").instantiate()
 root.add_child(panel)
 panel.request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
  var parser:=JSON.new()
  var parsed: Variant=parser.data if parser.parse(body.get_string_from_utf8())==OK else null
  print("LIVE HTTP: result=%d code=%d bytes=%d error=%s"%[result,code,body.size(),str(parsed.get("error","")) if parsed is Dictionary else "non-json"])
  for header in _headers:
   if header.to_lower().begins_with("location:"): print("REDIRECT: ",header.get_slice("?",0))
 )
 panel.request.max_redirects=0
 panel.sheets_url = OS.get_environment("LAKEBOUND_QA_URL")
 expect(SheetsRankingSync.is_endpoint(panel.sheets_url),"live Web App URL configured")
 var first_start:=Time.get_ticks_usec()
 panel.open()
 await wait_request(panel)
 print("LIVE FIRST FRESH RESPONSE: %.3f ms"%(float(Time.get_ticks_usec()-first_start)/1000.0))
 expect(panel.online,"real Godot HTTPS receives and decodes ranking: "+panel.get_node("%Status").text)
 if not panel.online:
  panel.queue_free()
  quit(1)
  return
 expect(panel.sheets_sync.read_only and panel.sheets_sync.acknowledged_name.is_empty(),"score-free first view uses GET without unnecessary registration")
 panel.close()
 var cached_start:=Time.get_ticks_usec()
 panel.open()
 var cached_ms:=float(Time.get_ticks_usec()-cached_start)/1000.0
 expect(panel.displaying_cached and cached_ms<1000.0,"cached board is displayed below one second before HTTP completes")
 print("LIVE CACHED BOARD OPEN: %.3f ms"%cached_ms)
 await wait_request(panel)
 print("LIVE CACHED REFRESH RESPONSE: %.3f ms"%(float(Time.get_ticks_usec()-cached_start)/1000.0))
 expect(panel.online and panel.sheets_sync.read_only,"next board open uses real HTTPS GET without reupload")
 panel._mode_changed(1)
 await wait_request(panel)
 expect(panel.online,"real map-specific ranking request succeeds")
 panel.top_limit = 100
 panel._selection_changed()
 await wait_request(panel)
 expect(panel.online,"real Top100 request succeeds")
 panel.close()
 panel.queue_free()
 print("SHEETS LIVE HTTP RESULT: %d failures" % failures)
 quit(1 if failures else 0)
