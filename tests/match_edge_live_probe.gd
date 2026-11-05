extends SceneTree
var service: Node
var received:=0
var fish_attempted:=false
var fish_ok:=false
var ready_sent:=false
var start_sent:=false
var loaded_sent:=false
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if OS.get_environment("LAKEBOUND_EDGE_QA")!="1":quit(1);return
 service=root.get_node("Competition")
 root.get_node("RankingOnline").enabled=false
 var profile=root.get_node("AnglerSave")
 profile.data=profile.defaults();profile.data.identity.name="QA Edge"
 service._identity=str(profile.data.identity.id);service._pending_room=""
 var auth=load("res://tests/fixtures/edge_auth_stub.gd").new()
 auth.access_token="qa."+service._identity+".signature";auth.expires_at=Time.get_unix_time_from_system()+3600
 root.add_child(auth);service.account_auth=auth
 service.pose_received.connect(func(pose: Dictionary):
  if pose.get("_webrtc",false):received+=1)
 var until:=Time.get_ticks_msec()+60000
 service.action("quick_join")
 while Time.get_ticks_msec()<until:
  await process_frame
  if service.room.is_empty():continue
  var phase: String=service.phase()
  if phase=="lobby":
   if not ready_sent:ready_sent=true;service.action("ready",{"ready":true})
   if service.room.host==service._identity and service.room.members.size()>=2 and service.room.members.all(func(m):return m.ready) and not start_sent:start_sent=true;service.action("start")
  elif phase=="loading" and not loaded_sent:loaded_sent=true;service.action("loaded")
  elif phase=="running":
   service.send_pose(Vector3.ONE,0,3,0,Vector3(3,0,0))
   if not fish_attempted:
    fish_attempted=true
    var claim: Dictionary=await service.reserve_fish(1,"tilapia",2345)
    if not claim.is_empty():fish_ok=service.submit_catch("tilapia",2345,Crypto.new().generate_random_bytes(16).hex_encode(),claim)
   if received>=60 and service.room.get("consumed_fish",[]).has(1.0):
    var total:=0
    for m in service.room.members:total+=int(m.grams)
    finish(total==2345 and service.realtime.socket==null);return
 finish(false)
func finish(ok: bool) -> void:
 var result:={"ok":ok,"rtc_received":received,"rtc_sent":service.rtc.sent,"edge_connected":service.edge.connected,"legacy_broadcast":service.realtime.socket!=null,"fish_won":fish_ok,"error":service.error_message,"rtc_error":service.rtc.last_error,"phase":service.phase()}
 var name:=OS.get_environment("LAKEBOUND_EDGE_QA_NAME")
 var file:=FileAccess.open("res://exports/qa-two-player/edge-"+name+".json",FileAccess.WRITE);file.store_string(JSON.stringify(result))
 print("EDGE GAME RESULT ",JSON.stringify(result));service.rtc.shutdown();service.edge.close();quit(0 if ok else 1)
