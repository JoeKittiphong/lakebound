extends Node
## Cloudflare room control. Never sends the permanent profile token.
signal snapshot_received(value: Dictionary)
signal pose_received(value: Dictionary)
signal connection_changed(value: bool)
signal heartbeat
signal social_changed
var social: Dictionary={}
var _social_server_time:=0.0
var _social_received_at:=0
var enabled:=false
var endpoint:=""
var connected:=false
var socket: WebSocketPeer
var _ticket:=""
var _jwt:=""
var _connecting:=false
var _sent_auth:=false
var _sequence:=0
var _replies: Dictionary={}
var _waiting: Dictionary={}
var _signals: Array=[]
var _ping_clock:=0.0
var _heard:=0
var _generation:=0
var last_error:=""
var _blocked_jwt:=""
@onready var request: HTTPRequest=$SessionRequest

func setup() -> void:
 var cfg:=ConfigFile.new()
 if cfg.load("res://online.cfg")==OK:
  endpoint=str(cfg.get_value("match_edge","url",""))
  enabled=bool(cfg.get_value("match_edge","enabled",false))
 var override:=OS.get_environment("LAKEBOUND_MATCH_EDGE_URL")
 if not override.is_empty(): endpoint=override;enabled=true
 if OS.get_environment("LAKEBOUND_MATCH_EDGE")=="0":enabled=false
 if not valid_endpoint(endpoint):enabled=false
 if OS.has_feature("web"):request.accept_gzip=false

static func valid_endpoint(value: String) -> bool:
 if value.ends_with("/") or value.contains("?") or value.contains("#") or value.contains("@"):return false
 return value.begins_with("https://") or value.begins_with("http://127.0.0.1:")

func close(clear_session := false) -> void:
 if clear_session:_blocked_jwt=""
 _generation+=1
 if socket!=null:socket.close()
 socket=null;_ticket="";connected=false;_sent_auth=false;_jwt="";_signals.clear();_replies.clear()
 social.clear();_social_server_time=0.0;social_changed.emit()
 for id in _waiting:_replies[id]={"error":"network_error"}
 connection_changed.emit(false)

func _process(delta: float) -> void:
 if socket==null:return
 socket.poll()
 if socket.get_ready_state()==WebSocketPeer.STATE_OPEN:
  if not _sent_auth:
   _sent_auth=true;socket.send_text(JSON.stringify({"type":"auth","ticket":_ticket}));_ticket=""
  var count:=0
  while socket.get_available_packet_count()>0 and count<128:
   count+=1
   var raw:=socket.get_packet()
   if raw.size()>65536:close();return
   var text:=raw.get_string_from_utf8()
   _heard=Time.get_ticks_msec()
   if text=="pong":heartbeat.emit();continue
   var value: Variant=JSON.parse_string(text)
   if not value is Dictionary:continue
   match str(value.get("type","")):
    "authenticated":connected=true;last_error="";connection_changed.emit(true)
    "reply":
     var id:=int(value.get("request_id",-1))
     if _waiting.has(id) and value.get("result") is Dictionary:_replies[id]=value.result
    "snapshot":
     if value.get("room") is Dictionary:snapshot_received.emit(value.room)
    "pose":
     if value.get("pose") is Dictionary:pose_received.emit(value.pose)
    "rtc_signal":
     if _signals.size()<128:_signals.append(value)
    "social":
     if value.get("state") is Dictionary:receive_social(value.state)
    "friend_presence":
     for friend in social.get("friends",[]):
      if friend.id==value.get("id"):friend.status=value.get("status","offline")
     social_changed.emit()
  _ping_clock+=delta
  if connected and _ping_clock>=25:_ping_clock=0;socket.send_text("ping")
  if connected and Time.get_ticks_msec()-_heard>45000:close()
 elif socket.get_ready_state()==WebSocketPeer.STATE_CLOSED:
  if socket.get_close_code()==4001:_blocked_jwt=_jwt
  last_error="superseded_session" if socket.get_close_code()==4001 else "network_error"
  close()

func receive_social(value: Dictionary) -> void:
 social=value
 _social_server_time=float(value.get("server_time",0.0))
 _social_received_at=Time.get_ticks_msec()
 social_changed.emit()

func social_now() -> float:
 # Device wall clocks can be minutes ahead. Expiry belongs to the server clock.
 if _social_server_time>0.0:return _social_server_time+(Time.get_ticks_msec()-_social_received_at)/1000.0
 return Time.get_unix_time_from_system()

func ensure_session(jwt: String) -> bool:
 if jwt==_blocked_jwt and not jwt.is_empty():return false
 if connected and _jwt==jwt:return true
 if _connecting:
  var waiting_until:=Time.get_ticks_msec()+12000
  while _connecting and Time.get_ticks_msec()<waiting_until:await get_tree().process_frame
  return connected and _jwt==jwt
 _connecting=true;close()
 var generation:=_generation
 if not enabled or jwt.is_empty():_connecting=false;return false
 var headers:=PackedStringArray(["Content-Type: application/json","Authorization: Bearer "+jwt])
 if request.request(endpoint+"/v1/session",headers,HTTPClient.METHOD_POST,"{}")!=OK:_connecting=false;return false
 var response: Array=await request.request_completed
 if generation!=_generation:_connecting=false;return false
 var value: Variant=JSON.parse_string(response[3].get_string_from_utf8())
 if response[0]!=HTTPRequest.RESULT_SUCCESS or response[1]!=200 or not value is Dictionary or not value.get("ticket") is String or value.ticket.length()!=64:
  last_error=str(value.get("error","network_error")) if value is Dictionary else "network_error"
  _connecting=false;return false
 _ticket=value.ticket;_jwt=jwt;socket=WebSocketPeer.new();socket.inbound_buffer_size=262144;socket.outbound_buffer_size=262144
 var ws_url:=endpoint.replace("https://","wss://").replace("http://","ws://")+"/v1/socket"
 if socket.connect_to_url(ws_url)!=OK:close();_connecting=false;return false
 _heard=Time.get_ticks_msec();_ping_clock=0
 var until:=Time.get_ticks_msec()+10000
 while not connected and socket!=null and Time.get_ticks_msec()<until:await get_tree().process_frame
 _connecting=false
 if not connected:close()
 return connected

func call_server(kind: String,payload: Dictionary) -> Dictionary:
 if not connected or socket==null:return {"error":"network_error"}
 if _waiting.size()>=8:return {"error":"busy_retry"}
 _sequence+=1
 var id:=_sequence
 _waiting[id]=true
 var outgoing:=payload.duplicate(true)
 outgoing.erase("token");outgoing.erase("player_name");outgoing.erase("player_id");outgoing.erase("_claim_ticket")
 if socket.send_text(JSON.stringify({"type":kind,"request_id":id,"payload":outgoing}))!=OK:_waiting.erase(id);return {"error":"network_error"}
 var until:=Time.get_ticks_msec()+10000
 while not _replies.has(id) and connected and Time.get_ticks_msec()<until:await get_tree().process_frame
 var result: Dictionary=_replies.get(id,{"error":"network_error"})
 _waiting.erase(id);_replies.erase(id)
 if kind=="rtc" and not result.has("error"):
  var messages: Array=[]
  for entry in _signals:
   if entry.get("room_id")==payload.get("room_id") and entry.get("round_id")==payload.get("round_id"):messages.append(entry.message)
  _signals.clear();result.signals=messages
 return result

func send_pose(pose: Dictionary,room_id: String) -> void:
 if not connected or socket==null or socket.get_current_outbound_buffered_amount()>16384:return
 var value:=pose.duplicate(true);value.room_id=room_id
 socket.send_text(JSON.stringify({"type":"pose","payload":value}))
