extends RefCounted
## Transport experiment only. No scoring, auth, room policy or game integration.
signal description_ready(kind: String, sdp: String)
signal candidate_ready(mid: String, index: int, candidate: String)
signal pose_received(value: Dictionary)
var connection: WebRTCPeerConnection
var channel: WebRTCDataChannel
var _pending: Array[Dictionary]=[]
var _remote_ready:=false
var _sequence:=-1
var sent:=0
var received:=0

func initialize(ice_servers: Array = []) -> Error:
 connection=WebRTCPeerConnection.new()
 var error:=connection.initialize({"iceServers":ice_servers})
 if error!=OK: return error
 channel=connection.create_data_channel("lakebound-pose",{"negotiated":true,"id":0,"ordered":false,"maxRetransmits":0})
 if channel==null: return ERR_CANT_CREATE
 channel.write_mode=WebRTCDataChannel.WRITE_MODE_TEXT
 connection.session_description_created.connect(func(kind: String,sdp: String):
  if connection.set_local_description(kind,sdp)==OK: description_ready.emit(kind,sdp))
 connection.ice_candidate_created.connect(func(mid: String,index: int,candidate: String): candidate_ready.emit(mid,index,candidate))
 return OK

func accept_description(kind: String,sdp: String) -> Error:
 if kind not in ["offer","answer"] or sdp.length()>60000: return ERR_INVALID_DATA
 var error:=connection.set_remote_description(kind,sdp)
 if error==OK:
  _remote_ready=true
  for c in _pending: connection.add_ice_candidate(c.mid,c.index,c.candidate)
  _pending.clear()
 return error

func accept_candidate(mid: String,index: int,candidate: String) -> void:
 if candidate.length()>2048 or index<0: return
 if _remote_ready: connection.add_ice_candidate(mid,index,candidate)
 elif _pending.size()<128: _pending.append({"mid":mid,"index":index,"candidate":candidate})

func poll() -> void:
 if connection==null: return
 connection.poll()
 if channel==null or channel.get_ready_state()!=WebRTCDataChannel.STATE_OPEN: return
 var count:=0
 while channel.get_available_packet_count()>0 and count<128:
  count+=1
  var packet:=channel.get_packet()
  if packet.size()>1024: continue
  var value: Variant=JSON.parse_string(packet.get_string_from_utf8())
  if not valid_pose(value) or int(value.seq)<=_sequence: continue
  _sequence=int(value.seq);received+=1;pose_received.emit(value)

func send_pose(value: Dictionary) -> Error:
 if not valid_pose(value): return ERR_INVALID_DATA
 if channel==null or channel.get_ready_state()!=WebRTCDataChannel.STATE_OPEN: return ERR_UNCONFIGURED
 var packet:=JSON.stringify(value).to_utf8_buffer()
 if packet.size()>1024: return ERR_INVALID_DATA
 var error:=channel.put_packet(packet)
 if error==OK: sent+=1
 return error

func close() -> void:
 for signal_name in ["description_ready","candidate_ready"]:
  for listener in get_signal_connection_list(signal_name): disconnect(signal_name,listener.callable)
 if channel!=null: channel.close()
 if connection!=null:
  for signal_name in ["session_description_created","ice_candidate_created"]:
   for listener in connection.get_signal_connection_list(signal_name): connection.disconnect(signal_name,listener.callable)
  connection.close()
 channel=null;connection=null;_pending.clear();_remote_ready=false;_sequence=-1

static func valid_pose(value: Variant) -> bool:
 if not value is Dictionary or not value.get("id") is String or value.id.length()!=32 or not value.id.is_valid_hex_number(): return false
 if not value.get("p") is Array or value.p.size()!=3: return false
 for n in value.p:
  if not (n is int or n is float) or not is_finite(float(n)) or absf(float(n))>100000: return false
 for key in ["yaw","speed","state","seq"]:
  if not (value.get(key) is int or value.get(key) is float) or not is_finite(float(value[key])): return false
 return value.seq>=0 and float(value.seq)==floor(float(value.seq)) and value.speed>=0 and value.speed<=20 and value.state>=0 and value.state<=6 and absf(float(value.yaw))<=TAU*2
