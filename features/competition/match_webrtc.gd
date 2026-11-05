extends Node
## Only cosmetic poses use WebRTC. Auth, fish claims and scoring stay in Supabase.
signal pose_received(pose: Dictionary)
const LINK=preload("res://features/competition/webrtc_pose_link.gd")
var enabled:=false
var service: Node
var links: Dictionary={}
var last_error:=""
var sent:=0
var received:=0
var _room:=""
var _round:=""
var _session:=""
var _cursor:=0
var _opened:=false
var _busy:=false
var _generation:=0
var _clock:=0.0
var _ice: Array=[]
var _ice_until:=0.0
var _outbox: Array[Dictionary]=[]
var _roster: Dictionary={}
var _restart_attempts:=0
var _blocked_round:=""
@onready var control_request: HTTPRequest=$ControlRequest
@onready var turn_request: HTTPRequest=$TurnRequest

func setup(value: Node) -> void:
 service=value
 var cfg:=ConfigFile.new()
 if cfg.load("res://online.cfg")==OK: enabled=bool(cfg.get_value("webrtc","enabled",false))
 if OS.get_environment("LAKEBOUND_WEBRTC")=="1": enabled=true
 if OS.get_environment("LAKEBOUND_WEBRTC")=="0": enabled=false
 if OS.has_feature("web"):
  control_request.accept_gzip=false
  turn_request.accept_gzip=false

func shutdown() -> void:
 _generation+=1
 for link in links.values(): link.peer.close()
 links.clear();_outbox.clear();_roster.clear();_ice.clear()
 _room="";_round="";_session="";_opened=false;_cursor=0;_clock=0

func _process(delta: float) -> void:
 for link in links.values(): link.peer.poll()
 if service==null: return
 if not enabled or not service.enabled or service.room.is_empty() or service.phase() not in ["lobby","loading","countdown","running"]:
  if not _room.is_empty(): shutdown()
  return
 if _blocked_round==str(service.room.round_id): return
 if _room!=str(service.room.id) or _round!=str(service.room.round_id):
  _restart_attempts=0
  shutdown();_room=str(service.room.id);_round=str(service.room.round_id);_session=Crypto.new().generate_random_bytes(16).hex_encode();_clock=5.0
 for link in links.values():
  var state: int=link.peer.connection.get_connection_state() if link.peer.connection!=null else WebRTCPeerConnection.STATE_CLOSED
  var age_ms: int=Time.get_ticks_msec()-int(link.born)
  if state==WebRTCPeerConnection.STATE_CONNECTED: link.last_ok=Time.get_ticks_msec()
  var disconnected: bool=state==WebRTCPeerConnection.STATE_DISCONNECTED and Time.get_ticks_msec()-int(link.get("last_ok",link.born))>10000
  if disconnected or (state in [WebRTCPeerConnection.STATE_FAILED,WebRTCPeerConnection.STATE_CLOSED] and age_ms>3000) or (state in [WebRTCPeerConnection.STATE_NEW,WebRTCPeerConnection.STATE_CONNECTING] and age_ms>25000):
   _restart_session()
   return
 if not _ice.is_empty() and Time.get_unix_time_from_system()>=_ice_until:
  _restart_session()
  return
 if not service.connected or Time.get_ticks_msec()-service._clock_ticks>=45000: return
 _clock+=delta
 if not _busy and not service._access.is_empty() and _clock>=(3.0 if all_ready() and _outbox.is_empty() else 1.0):
  _clock=0
  _refresh()

func _restart_session() -> void:
 _restart_attempts+=1
 var room_id:=_room;var round_id:=_round
 shutdown()
 if _restart_attempts>3:
  _blocked_round=round_id;last_error="rtc_retry_exhausted";return
 _room=room_id;_round=round_id;_session=Crypto.new().generate_random_bytes(16).hex_encode();_clock=-2.0-randf()

func all_ready() -> bool:
 if not enabled or not _opened or links.is_empty() or service==null or service.room.is_empty() or Time.get_unix_time_from_system()>=_ice_until: return false
 for member in service.room.get("members",[]):
  if member.id==service._identity or member.get("departed",false): continue
  if not links.has(member.id) or links[member.id].peer.channel==null or links[member.id].peer.channel.get_ready_state()!=WebRTCDataChannel.STATE_OPEN: return false
 return true

func send_pose(pose: Dictionary) -> int:
 var delivered:=0
 for link in links.values():
  if link.peer.channel!=null and link.peer.channel.get_buffered_amount()<16384 and link.peer.send_pose(pose)==OK:
   delivered+=1;sent+=1
 return delivered

func _post(node: HTTPRequest,path: String,payload: Dictionary) -> Dictionary:
 if service.get("edge")!=null and service.edge.enabled:
  return await service.edge.call_server("rtc",payload.get("payload",payload)) if path.ends_with("lakebound_rtc") else await service.edge.call_server("turn",payload)
 var headers:=PackedStringArray(["Content-Type: application/json","apikey: "+service.api_key,"Authorization: Bearer "+service._access])
 if node.request(service.base_url+path,headers,HTTPClient.METHOD_POST,JSON.stringify(payload))!=OK: return {"error":"rtc_network_error"}
 var result: Array=await node.request_completed
 if result[0]!=HTTPRequest.RESULT_SUCCESS or result[3].size()>65536: return {"error":"rtc_network_error"}
 var value: Variant=JSON.parse_string(result[3].get_string_from_utf8())
 if not value is Dictionary: return {"error":"rtc_invalid_response"}
 if result[1]!=200: return {"error":str(value.get("error","rtc_request_rejected"))}
 return value

func _refresh() -> void:
 _busy=true
 var generation:=_generation
 var identity: Dictionary=service.profile.data.identity
 var common:={"player_id":str(identity.id),"player_name":str(identity.name),"token":str(identity.token),"room_id":_room,"round_id":_round}
 if _ice.is_empty() or Time.get_unix_time_from_system()>=_ice_until:
  var credentials:=await _post(turn_request,"/functions/v1/lakebound-turn",common)
  if generation!=_generation: _busy=false;return
  if credentials.has("error") or not valid_ice(credentials):
   last_error=str(credentials.get("error","rtc_invalid_ice"));_clock=-4;_busy=false;return
  _ice=credentials.iceServers
  _ice_until=Time.get_unix_time_from_system()+float(credentials.expiresIn)-30
 var op:="open" if not _opened else ("send" if not _outbox.is_empty() else "poll")
 var batch: Array=[]
 if op=="send":
  var size:=0
  while batch.size()<16 and not _outbox.is_empty():
   var item_size:=JSON.stringify(_outbox[0]).to_utf8_buffer().size()
   if size+item_size>36000: break
   batch.append(_outbox.pop_front());size+=item_size
 common.merge({"op":op,"session_id":_session,"cursor":_cursor})
 if op=="send": common.items=batch
 var response:=await _post(control_request,"/rest/v1/rpc/lakebound_rtc",{"payload":common})
 _busy=false
 if generation!=_generation: return
 if response.has("error"):
  last_error=str(response.error)
  if op=="send" and _outbox.size()+batch.size()<=128:
   batch.append_array(_outbox);_outbox.assign(batch)
  if last_error=="stale_rtc_session":
   # Another login owns this player: do not fight it with repeated open calls.
   shutdown();enabled=false
  _clock=-2
  return
 if response.get("room_id","")!=_room or response.get("round_id","")!=_round or not response.get("peers") is Array or not response.get("signals") is Array: last_error="rtc_invalid_response";return
 _opened=true;last_error=""
 _apply_roster(response.peers)
 for message in response.signals:
  if not message is Dictionary: continue
  _cursor=maxi(_cursor,int(message.get("id",0)))
  if not links.has(str(message.get("from",""))): continue
  var id:=str(message.from)
  if str(message.get("session",""))!=str(links[id].session): continue
  var peer=links[id].peer
  var kind:=str(message.get("kind",""))
  if kind in ["offer","answer"] and message.get("data") is String: peer.accept_description(kind,message.data)
  elif kind=="candidate" and message.get("data") is Dictionary:
   var c: Dictionary=message.data
   if c.get("mid") is String and c.get("candidate") is String and (c.get("index") is int or c.get("index") is float): peer.accept_candidate(c.mid,int(c.index),c.candidate)

func _apply_roster(rows: Array) -> void:
 var next: Dictionary={}
 for row in rows:
  if not row is Dictionary: continue
  var id:=str(row.get("player_id",""));var session:=str(row.get("session_id",""))
  if id==service._identity or service.member(id).is_empty() or service.member(id).get("departed",false) or id.length()!=32 or session.length()!=32: continue
  next[id]=session
 for id in links.keys():
  if not next.has(id) or links[id].session!=next[id]: links[id].peer.close();links.erase(id)
 _roster=next
 for id in next:
  if links.has(id): continue
  var peer=LINK.new()
  if peer.initialize(_ice)!=OK: peer.close();last_error="rtc_native_unavailable";enabled=false;return
  var session: String=next[id]
  links[id]={"peer":peer,"session":session,"born":Time.get_ticks_msec()}
  peer.description_ready.connect(func(kind: String,sdp: String): _queue_signal(id,session,kind,sdp))
  peer.candidate_ready.connect(func(mid: String,index: int,candidate: String): _queue_signal(id,session,"candidate",{"mid":mid,"index":index,"candidate":candidate}))
  peer.pose_received.connect(func(value: Dictionary):
   if links.has(id) and links[id].session==session and value.get("id","")==id and MatchRealtime.valid_pose(value): received+=1;pose_received.emit(value))
  if service._identity<id: peer.connection.create_offer()

func _queue_signal(id: String,session: String,kind: String,data: Variant) -> void:
 if _outbox.size()<128: _outbox.append({"to":id,"to_session":session,"kind":kind,"data":data})

static func valid_ice(value: Dictionary) -> bool:
 if not value.get("iceServers") is Array or value.iceServers.is_empty() or value.iceServers.size()>8: return false
 if not (value.get("expiresIn") is int or value.get("expiresIn") is float) or not is_finite(float(value.expiresIn)) or float(value.expiresIn)<60 or float(value.expiresIn)>3600: return false
 for server in value.iceServers:
  if not server is Dictionary or not server.get("urls") is Array or server.urls.size()>12: return false
  for url in server.urls:
   if not url is String or url.length()>256 or not (url.begins_with("stun:") or url.begins_with("turn:") or url.begins_with("turns:")): return false
 return true

func _exit_tree() -> void: shutdown()
