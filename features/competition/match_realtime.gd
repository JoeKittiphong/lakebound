class_name MatchRealtime
extends RefCounted
## Phoenix v1 JSON protocol. Positions are cosmetic; scores never come from Broadcast.
signal pose_received(pose: Dictionary)
signal connection_changed(connected: bool)
var socket: WebSocketPeer
var topic := ""
var player_id := ""
var joined := false
var _ref := 0
var _heartbeat := 0.0
var _join_ref := ""
var _last_receive := 0.0
var _sequences := {}
var last_error := ""

func connect_room(base_url: String, key: String, jwt: String, room: String, identity: String) -> void:
 close()
 last_error=""
 player_id = identity
 topic = "realtime:match:" + room
 socket = WebSocketPeer.new()
 socket.inbound_buffer_size = 65536
 socket.outbound_buffer_size = 65536
 socket.max_queued_packets = 64
 var error := socket.connect_to_url(base_url.replace("https://", "wss://") + "/realtime/v1/websocket?apikey=" + key.uri_encode() + "&vsn=1.0.0")
 if error != OK: last_error="connect_error_"+str(error); close(); return
 # Join is sent once the socket opens, by poll().
 _jwt = jwt

var _jwt := ""
func close() -> void:
 if socket != null: socket.close()
 socket = null
 joined = false
 _join_ref = ""
 _heartbeat = 0.0
 _sequences.clear()
 connection_changed.emit(false)

func poll(delta: float) -> void:
 if socket == null: return
 socket.poll()
 if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
  if last_error.is_empty(): last_error="socket_closed_"+str(socket.get_close_code())
  close()
  return
 if socket.get_ready_state() != WebSocketPeer.STATE_OPEN: return
 if _join_ref.is_empty():
  _join_ref = _send(topic, "phx_join", {"config":{"private":true,"broadcast":{"ack":false,"self":false},"presence":{"key":player_id}},"access_token":_jwt})
  _jwt = ""
  _last_receive = Time.get_ticks_msec() / 1000.0
 _heartbeat += delta
 if _heartbeat >= 20.0:
  _heartbeat = 0.0
  _send("phoenix", "heartbeat", {})
 while socket.get_available_packet_count() > 0:
  var packet := socket.get_packet()
  if packet.size() > 16384: continue
  var message: Variant = JSON.parse_string(packet.get_string_from_utf8())
  if not message is Dictionary: continue
  _last_receive = Time.get_ticks_msec() / 1000.0
  if message.get("topic", "") != topic: continue
  var payload: Variant = message.get("payload", {})
  if not payload is Dictionary: continue
  if message.get("event") == "phx_reply" and str(message.get("ref", "")) == _join_ref:
   joined = payload.get("status") == "ok"
   connection_changed.emit(joined)
   if not joined:
    var response: Variant=payload.get("response",{})
    last_error=str(response.get("reason",response.get("message","join_rejected"))) if response is Dictionary else "join_rejected"
    close(); return
  elif message.get("event") == "broadcast" and payload.get("event") == "pose":
   var pose: Variant = payload.get("payload", {})
   if valid_pose(pose) and pose.id != player_id and int(pose.seq) > int(_sequences.get(pose.id,-1)):
    _sequences[pose.id] = int(pose.seq)
    pose_received.emit(pose)
  elif message.get("event") in ["phx_error", "phx_close"]:
   last_error=str(message.get("event"))
   close(); return
 if Time.get_ticks_msec()/1000.0 - _last_receive > 45.0:
  last_error="heartbeat_timeout"
  close()

func send_pose(pose: Dictionary) -> void:
 if joined and valid_pose(pose): _send(topic,"broadcast",{"type":"broadcast","event":"pose","payload":pose})

func _send(channel: String, event: String, payload: Dictionary) -> String:
 _ref += 1
 if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
  socket.send_text(JSON.stringify(protocol_message(channel,event,payload,_ref,_join_ref)))
 return str(_ref)

static func protocol_message(channel: String, event: String, payload: Dictionary, reference: int, join_reference: String) -> Dictionary:
 # Phoenix associates every subsequent push with the join's original ref.
 # Sending an empty join_ref on phx_join but a numbered ref on Broadcast lets
 # the channel join succeed while silently discarding subsequent pushes.
 var join_value: Variant=null
 if channel.begins_with("realtime:"): join_value=str(reference) if event=="phx_join" else join_reference
 return {"topic":channel,"event":event,"payload":payload,"ref":str(reference),"join_ref":join_value}

static func valid_pose(value: Variant) -> bool:
 if not value is Dictionary or value.size()>10: return false
 if not value.get("id") is String or not str(value.id).is_valid_hex_number() or str(value.id).length()!=32: return false
 if not value.get("p") is Array or value.p.size()!=3: return false
 for coordinate in value.p:
  if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or absf(float(coordinate))>100000: return false
 for field in ["yaw","speed","state","seq"]:
  if not (value.get(field) is float or value.get(field) is int) or not is_finite(float(value[field])): return false
 if value.has("v"):
  if not value.v is Array or value.v.size()!=2: return false
  for component in value.v:
   if not (component is float or component is int) or not is_finite(float(component)) or absf(float(component))>20: return false
 return float(value.speed)>=0 and float(value.speed)<=20 and float(value.state)>=0 and float(value.state)<=6 and float(value.seq)>=0 and absf(float(value.yaw))<=TAU*2
