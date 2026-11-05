extends SceneTree
var service: Node
var finish_at:=0
var rtc_count:=0
var broadcast_count:=0
var ready_sent:=false
var start_sent:=false
var loaded_sent:=false
var last_action:=0
var pose_clock:=0.0
var phase_clock:=0.0
var passed_at:=0
var last_status:=0
var fresh_done:=false
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if OS.get_environment("LAKEBOUND_RTC_LIVE_PROBE")!="1":quit(1);return
 service=root.get_node("Competition")
 service.pose_received.connect(func(pose: Dictionary):
  if pose.get("_webrtc",false):rtc_count+=1
  else:broadcast_count+=1)
 finish_at=Time.get_ticks_msec()+90000
 while Time.get_ticks_msec()<finish_at:
  await process_frame
  var auth: Node=root.get_node("AccountAuth")
  if not auth.signed_in():continue
  if not fresh_done and OS.get_environment("LAKEBOUND_RTC_PROBE_FRESH")=="1" and service.using_edge():
   fresh_done=true;service.forget_room()
   if await service._authenticate() and await service.edge.ensure_session(service._access):
    var previous: Dictionary=await service.edge.call_server("command",{"op":"quick_join"})
    if previous.has("id"):await service.edge.call_server("command",{"op":"leave","room_id":previous.id})
   service.forget_room()
   continue
  if service.room.is_empty():
   if not service.busy and service._queue.is_empty() and Time.get_ticks_msec()-last_action>1500:
    last_action=Time.get_ticks_msec()
    service.action("create",{"map":"river","duration":600,"rule":"total_weight"}) if service.error_message=="no_open_rooms" else service.action("quick_join")
   continue
  var phase: String=service.phase()
  if phase=="finished" or phase=="cancelled":
   if service.room.host==service._identity and not service.busy and service._queue.is_empty():service.action("rematch")
   continue
  if phase=="lobby":
   if not ready_sent:ready_sent=true;service.action("ready",{"ready":true})
   if service.room.host==service._identity and service.room.members.size()>=2 and service.room.members.all(func(m):return m.ready) and not start_sent:
    start_sent=true;service.action("start")
  elif phase=="loading" and not loaded_sent:loaded_sent=true;service.action("loaded")
  elif phase=="running":
   pose_clock=Time.get_ticks_msec()/1000.0
   service.send_pose(Vector3(sin(pose_clock)*2,0,cos(pose_clock)*2),fmod(pose_clock,TAU),3,0,Vector3(3,0,0))
   if service.rtc.all_ready() and rtc_count>=60:
    if passed_at==0:passed_at=Time.get_ticks_msec()
  if passed_at>0 and Time.get_ticks_msec()-passed_at>2000:finish(true);return
  if Time.get_ticks_msec()-last_status>5000:
   last_status=Time.get_ticks_msec()
   var states: Array=[]
   for link in service.rtc.links.values():states.append(link.peer.connection.get_connection_state())
   print("RTC LIVE STATUS ",JSON.stringify({"phase":phase,"peers":service.rtc.links.size(),"rtc_error":service.rtc.last_error,"states":states,"rtc_received":rtc_count}))
 finish(false)
func finish(ok: bool) -> void:
 var report:={"ok":ok,"google_session":root.get_node("AccountAuth").signed_in(),"backend":"cloudflare" if service.using_edge() else "supabase","supabase_realtime":service.realtime.socket!=null,"phase":service.phase(),"rtc_received":rtc_count,"broadcast_received":broadcast_count,"rtc_sent":service.rtc.sent,"send_interval":service.pose_interval(),"error":service.rtc.last_error}
 var name:=OS.get_environment("LAKEBOUND_RTC_PROBE_NAME")
 var file:=FileAccess.open("res://exports/qa-two-player/rtc-"+name+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report))
 print("RTC LIVE RESULT ",JSON.stringify(report))
 service.rtc.shutdown()
 quit(0 if ok else 1)
