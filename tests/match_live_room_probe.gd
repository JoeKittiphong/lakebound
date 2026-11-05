extends SceneTree
## Explicit opt-in. Uses the current account and leaves its room available to resume.
var started := false
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 if OS.get_environment("LAKEBOUND_LIVE_ROOM_PROBE")!="1": quit(1); return
 var auth: Node=root.get_node("AccountAuth")
 auth.authenticated.connect(func():
  if not started:
   started=true
   probe.call_deferred())
 await create_timer(30).timeout
 if not started:
  finish({"google_session":auth.signed_in(),"account_needs_name":auth.needs_name,"room_accepted":false})
func probe() -> void:
 var service: Node=root.get_node("Competition")
 service.set_process(false)
 service._queue.clear()
 service.enabled=true
 service.action("create",{"map":"river","duration":600,"rule":"total_weight"})
 await service._pump()
 if service.error_message=="already_in_match":
  service.action("quick_join")
  await service._pump()
 var report := {"google_session":root.get_node("AccountAuth").signed_in(),"room_accepted":not service.room.is_empty(),"error":service.error_message}
 if not service.room.is_empty():
  report["valid_http_snapshot"]=service.valid_snapshot(service.room)
  report["five_digit_code"]=service.valid_room_code(str(service.room.code))
  report["duration_from_json_is_float"]=service.room.duration is float
  report["fish_ownership_protocol"]=service.room.has("fish_claims") and service.room.has("consumed_fish")
  report["motion_interval_seconds"]=service.pose_interval()
 finish(report)
func finish(report: Dictionary) -> void:
 var file:=FileAccess.open("res://exports/qa-two-player/real-room-probe.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report))
 print("LIVE ROOM PROBE: ",JSON.stringify(report))
 quit(0 if report.get("room_accepted",false) else 1)
