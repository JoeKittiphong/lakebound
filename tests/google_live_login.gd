extends SceneTree
var _transport_started := false
var _sender: MatchRealtime
var _receiver: MatchRealtime
var _outsider: MatchRealtime
var _received := false
var _report: Dictionary={}

func _process(delta: float) -> bool:
 for connection in [_sender,_receiver,_outsider]:
  if connection!=null: connection.poll(delta)
 return false
## Opt-in desktop OAuth acceptance check. Uses an isolated APPDATA directory.
## Opens Google's own browser UI; never prints tokens or email addresses.
func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 if OS.get_environment("LAKEBOUND_GOOGLE_LIVE")!="1":
  print("Google live login requires LAKEBOUND_GOOGLE_LIVE=1")
  quit(1)
  return
 DisplayServer.window_set_title("Lakebound - Google Login QA")
 root.get_node("RankingOnline").enabled=false
 root.get_node("Competition").enabled=false
 var panel: Control=load("res://features/auth/login_panel.tscn").instantiate()
 root.add_child(panel)
 panel.open()
 var auth: Node=root.get_node("AccountAuth")
 auth.authenticated.connect(func():
  _report.merge({"google_session":auth.signed_in(),"account_ready":auth.account_ready,
   "player_identity_valid":AnglerIdentity.valid(root.get_node("AnglerSave").data.identity),
   "refresh_present":not auth.refresh_token.is_empty(),"new_account_namespace":root.get_node("AnglerSave").save_path.begins_with("user://accounts_v1/")},true)
  _save_report()
  print("GOOGLE LIVE LOGIN: ",JSON.stringify(_report))
  panel.open()
  _check_transport.call_deferred()
 )

func _save_report() -> void:
 var file := FileAccess.open("res://exports/qa-competition/google-live-login-result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(_report))

func _check_transport() -> void:
 if _transport_started: return
 _transport_started=true
 var auth: Node=root.get_node("AccountAuth")
 var identity: Dictionary=root.get_node("AnglerSave").data.identity
 var payload := {"player_id":identity.id,"token":identity.token,"player_name":identity.name}
 var room: Dictionary=await auth._http("/rest/v1/rpc/lakebound_matches",{"payload":payload.merged({"op":"create","map":"lotus_marsh"})},true)
 if not room.has("id"):
  _report["realtime_error"]="create_room_failed"
  _save_report()
  return
 _sender=MatchRealtime.new()
 _receiver=MatchRealtime.new()
 _outsider=MatchRealtime.new()
 _receiver.pose_received.connect(func(_pose: Dictionary): _received=true)
 _sender.connect_room(auth.base_url,auth.api_key,auth.access_token,str(room.id),str(identity.id))
 # Same authenticated player, two sockets: transport check, not two players.
 _receiver.connect_room(auth.base_url,auth.api_key,auth.access_token,str(room.id),"f".repeat(32))
 _outsider.connect_room(auth.base_url,auth.api_key,auth.access_token,"00000000-0000-4000-8000-000000000099",str(identity.id))
 var until := Time.get_ticks_msec()+12000
 while Time.get_ticks_msec()<until and not (_sender.joined and _receiver.joined): await process_frame
 _report["private_realtime_join"]=_sender.joined and _receiver.joined
 if not _sender.joined: _report["sender_error"]=_sender.last_error
 if not _receiver.joined: _report["receiver_error"]=_receiver.last_error
 _sender.send_pose({"id":identity.id,"p":[1,2,3],"yaw":0,"speed":0,"state":0,"seq":1})
 until=Time.get_ticks_msec()+5000
 while Time.get_ticks_msec()<until and not _received: await process_frame
 _report["private_broadcast_received"]=_received
 until=Time.get_ticks_msec()+8000
 while Time.get_ticks_msec()<until and _outsider.socket!=null and not _outsider.joined: await process_frame
 _report["nonmember_topic_rejected"]=not _outsider.joined and _outsider.socket==null
 if not _report.nonmember_topic_rejected: _report["outsider_error"]=_outsider.last_error
 for connection in [_sender,_receiver,_outsider]: connection.close()
 var left: Dictionary=await auth._http("/rest/v1/rpc/lakebound_matches",{"payload":payload.merged({"op":"leave","room_id":room.id})},true)
 _report["test_room_closed"]=left.get("phase","")=="cancelled"
 _save_report()
 print("GOOGLE LIVE TRANSPORT: ",JSON.stringify(_report))
