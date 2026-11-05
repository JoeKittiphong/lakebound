extends Node
## Persistent room/session across menu, loading and gameplay. No service credentials.
signal changed
signal failed(reason: String)
signal pose_received(pose: Dictionary)
@export var enabled := true
@export_range(2.0,10.0) var refresh_seconds := 3.0
var room: Dictionary = {}
var busy := false
var connected := false
var error_message := ""
var realtime := MatchRealtime.new()
var profile: AnglerProfile
var base_url := ""
var api_key := ""
var _access := ""
var _refresh := ""
var _expires := 0.0
var _queue: Array[Dictionary] = []
var _elapsed := 0.0
var _retry_at := 0.0
var _clock_server := 0.0
var _clock_ticks := 0
var _pending_room := ""
var _identity := ""
var _sequence := int(Time.get_unix_time_from_system()*1000)
var _last_rt_attempt := 0.0
var _generation := 0
var _inflight_op := ""
var _retry_count := 0
var _last_pose_sent := -2000
var _motion_trace_at := -3000
var _motion_trace_lines := 0
var _last_broadcast_pose := -2000
var _remote_pose_sequence: Dictionary={}
var _claim_waiters := {}
var account_auth: Node
@onready var request: HTTPRequest = $Request
@onready var rtc: Node=$WebRTC
@onready var edge: Node=$Edge

func using_edge() -> bool:
 # AccountAuth can switch profiles before Competition's @onready bindings exist.
 if edge!=null:return edge.enabled
 var cfg:=ConfigFile.new()
 var selected:=false
 var endpoint:=""
 if cfg.load("res://online.cfg")==OK:
  selected=bool(cfg.get_value("match_edge","enabled",false));endpoint=str(cfg.get_value("match_edge","url",""))
 var override:=OS.get_environment("LAKEBOUND_MATCH_EDGE_URL")
 if not override.is_empty():endpoint=override;selected=true
 return selected and OS.get_environment("LAKEBOUND_MATCH_EDGE")!="0" and load("res://features/competition/match_edge.gd").valid_endpoint(endpoint)

func _ready() -> void:
 if OS.has_feature("web"): request.accept_gzip=false
 enabled = enabled and OS.get_environment("LAKEBOUND_COMPETITION") != "0"
 profile = get_node_or_null("/root/AnglerSave")
 account_auth=get_node_or_null("/root/AccountAuth")
 var config := ConfigFile.new()
 if config.load("res://online.cfg") == OK:
  var endpoint := str(config.get_value("supabase","url",""))
  if SupabaseConnectionSettings.valid_url(endpoint): base_url = endpoint.get_slice("/rest/",0)
  api_key = str(config.get_value("supabase","publishable_key",""))
 realtime.pose_received.connect(func(pose: Dictionary):
  _accept_pose(pose,false))
 rtc.setup(self)
 edge.setup()
 $Friends.setup(self)
 edge.snapshot_received.connect(_edge_snapshot)
 edge.pose_received.connect(func(pose: Dictionary):_accept_pose(pose,false))
 edge.connection_changed.connect(func(value: bool):
  if edge.enabled and not value:connected=false;changed.emit())
 edge.heartbeat.connect(func():
  if edge.enabled and connected and _expires>Time.get_unix_time_from_system():
   _clock_server=server_now();_clock_ticks=Time.get_ticks_msec())
 rtc.pose_received.connect(func(pose: Dictionary): _accept_pose(pose,true))
 realtime.connection_changed.connect(func(_value: bool): changed.emit())
 if profile != null: _identity = str(profile.data.identity.id)
 var saved := ConfigFile.new()
 if saved.load(PlayerSavePaths.MATCH_SESSION) == OK and saved.get_value("session","identity","") == _identity and saved.get_value("session","backend","supabase")==("cloudflare" if edge.enabled else "supabase"):
  _pending_room = str(saved.get_value("session","room",""))

func _process(delta: float) -> void:
 if not enabled: return
 realtime.poll(delta)
 _elapsed += delta
 if _elapsed >= maxf(refresh_seconds,float(room.get("poll_interval",5.0))) and (not edge.enabled or not edge.connected or _expires<Time.get_unix_time_from_system()+60):
  _elapsed = 0.0
  if not room.is_empty(): action("state")
  elif not _pending_room.is_empty(): action("state",{"room_id":_pending_room})
 if not busy and not _queue.is_empty() and Time.get_ticks_msec()/1000.0 >= _retry_at: _pump()
 var live_lease := connected and Time.get_ticks_msec()-_clock_ticks<45000
 var needs_realtime: bool = not edge.enabled and not room.is_empty() and phase() in ["loading","countdown","running"] and live_lease
 if not needs_realtime and realtime.socket!=null: realtime.close()
 if needs_realtime and realtime.socket == null and not _access.is_empty() and _expires>Time.get_unix_time_from_system()+60:
  var tick := Time.get_ticks_msec()/1000.0
  if tick-_last_rt_attempt>5:
   _last_rt_attempt=tick
   realtime.connect_room(base_url,api_key,_access,str(room.id),_identity)

func member(id: String) -> Dictionary:
 for item in room.get("members",[]):
  if item.id == id: return item
 return {}

func phase() -> String:
 if room.is_empty(): return "none"
 var value := str(room.phase)
 if value=="countdown" and server_now()>=float(room.starts_at): value="running"
 if value=="running" and server_now()>=float(room.ends_at): value="finishing"
 return value

func server_now() -> float:
 return _clock_server + (Time.get_ticks_msec()-_clock_ticks)/1000.0

func can_score() -> bool:
 return connected and phase()=="running" and not member(_identity).get("departed",true)

func action(op: String, data: Dictionary = {}) -> void:
 if not enabled or profile==null: return
 if not AnglerIdentity.valid_name(str(profile.data.identity.name)):
  _fail("name_required"); return
 if op in ["state","loaded","create","join","quick_join","renew_fish"]:
  if busy and _inflight_op==op: return
  for item in _queue:
   if item.op==op: return
 if _queue.size()>=220: _fail("queue_full"); return
 var item := data.duplicate(true)
 item.op = op
 if not item.has("room_id") and not room.is_empty(): item.room_id=room.id
 _queue.append(item)

func submit_catch(species: String, grams: int, catch_id: String, fish_claim: Dictionary = {}) -> bool:
 if not can_score(): return false
 if fish_claim.get("player_id","")!=_identity or fish_claim.get("round_id","")!=str(room.round_id) or str(fish_claim.get("claim_id","")).length()!=36: return false
 action("catch",{"species":species,"grams":grams,"catch_id":catch_id,"round_id":room.round_id,"fish_id":int(fish_claim.get("fish_id",0)),"claim_id":str(fish_claim.get("claim_id",""))})
 return true

func fish_claim(fish_id: int) -> Dictionary:
 for entry in room.get("fish_claims",[]):
  if int(entry[0])==fish_id:
   return {"fish_id":fish_id,"player_id":str(entry[1]),"claim_id":str(entry[2]),"expires_at":float(entry[3]),"species":str(entry[4]),"grams":int(entry[5]),"round_id":str(room.round_id)}
 return {}

func reserve_fish(fish_id: int, species: String, grams: int) -> Dictionary:
 if not can_score(): return {}
 var ticket := Crypto.new().generate_random_bytes(16).hex_encode()
 _claim_waiters[ticket]={}
 action("claim_fish",{"fish_id":fish_id,"species":species,"grams":grams,"round_id":room.round_id,"_claim_ticket":ticket})
 var until := Time.get_ticks_msec()+15000
 while _claim_waiters.has(ticket) and _claim_waiters[ticket].is_empty() and Time.get_ticks_msec()<until:
  await get_tree().process_frame
 var result: Dictionary=_claim_waiters.get(ticket,{})
 _claim_waiters.erase(ticket)
 for index in range(_queue.size()-1,-1,-1):
  if _queue[index].get("_claim_ticket","")==ticket: _queue.remove_at(index)
 if result.get("ok",false): return fish_claim(fish_id)
 return {}

func release_fish(claim: Dictionary) -> void:
 if claim.is_empty() or room.is_empty() or str(claim.get("round_id",""))!=str(room.round_id): return
 action("release_fish",{"fish_id":int(claim.fish_id),"claim_id":str(claim.claim_id),"round_id":room.round_id})

func _complete_claim(item: Dictionary, result: Dictionary) -> void:
 if item.op!="claim_fish": return
 var ticket: String=str(item.get("_claim_ticket",""))
 if _claim_waiters.has(ticket):
  _claim_waiters[ticket]={"ok":not result.has("error")}
 elif not result.has("error"):
  var claim := fish_claim(int(item.fish_id))
  if claim.get("player_id","")==_identity: release_fish(claim)

func _accept_pose(pose: Dictionary,via_rtc: bool) -> void:
 if room.is_empty() or member(pose.id).is_empty() or member(pose.id).get("departed",false): return
 if pose.has("round") and str(pose.round)!=str(room.round_id): return
 if int(pose.seq)<=int(_remote_pose_sequence.get(pose.id,-1)): return
 _remote_pose_sequence[pose.id]=int(pose.seq)
 var value:=pose.duplicate(true)
 value["_webrtc"]=via_rtc
 pose_received.emit(value)

func pose_interval() -> float:
 if rtc!=null and rtc.all_ready(): return 0.05
 return _broadcast_interval()

func _broadcast_interval() -> float:
 var value: Variant = room.get("pose_interval",2.0)
 if not (value is float or value is int) or not is_finite(float(value)): return 2.0
 return clampf(float(value),0.334,10.0)

func send_pose(position: Vector3, yaw: float, speed: float, state: int, velocity := Vector3.ZERO) -> bool:
 if room.is_empty() or phase()!="running" or not connected or Time.get_ticks_msec()-_clock_ticks>=45000: return false
 var rtc_ready: bool=rtc!=null and rtc.all_ready()
 var fallback_ready: bool=edge.connected if edge.enabled else realtime.joined
 if not fallback_ready and not rtc_ready: return false
 if Time.get_ticks_msec()-_last_pose_sent<int(ceil(pose_interval()*1000.0)): return false
 if OS.get_environment("LAKEBOUND_MOTION_DEBUG")=="1" and _motion_trace_lines<100 and Time.get_ticks_msec()-_motion_trace_at>=3000:
  print("MOTION_TX route=","webrtc" if rtc_ready else "broadcast"," gap_ms=",Time.get_ticks_msec()-_last_pose_sent," interval_ms=",int(ceil(pose_interval()*1000.0))," speed=",snappedf(speed,0.01))
  _motion_trace_at=Time.get_ticks_msec()
  _motion_trace_lines+=1
 _sequence += 1
 var pose:={"id":_identity,"p":[position.x,position.y,position.z],"yaw":yaw,"speed":speed,"state":state,"seq":_sequence,"v":[velocity.x,velocity.z],"round":str(room.round_id)}
 var delivered:=0
 if rtc!=null: delivered=int(rtc.send_pose(pose))
 var broadcast_sent:=false
 if not rtc_ready and fallback_ready and Time.get_ticks_msec()-_last_broadcast_pose>=int(ceil(_broadcast_interval()*1000.0)):
  if edge.enabled:edge.send_pose(pose,str(room.id))
  else:realtime.send_pose(pose)
  _last_broadcast_pose=Time.get_ticks_msec()
  broadcast_sent=true
 if delivered==0 and not broadcast_sent: return false
 _last_pose_sent=Time.get_ticks_msec()
 return true

func forget_room(close_transport := true) -> void:
 _generation += 1
 room.clear()
 _pending_room=""
 _queue.clear()
 _claim_waiters.clear()
 realtime.close()
 if rtc!=null: rtc.shutdown()
 if edge!=null and close_transport:edge.close(true)
 _remote_pose_sequence.clear()
 _save_session()
 changed.emit()

func _edge_snapshot(value: Dictionary) -> void:
 if not edge.enabled or not valid_snapshot(value):return
 if not room.is_empty() and value.id!=room.id:return
 if not room.is_empty() and float(value.server_time)<float(room.server_time):return
 if not value.members.any(func(m):return m.id==_identity and not m.departed):return
 room=value;connected=true;_pending_room=str(room.id)
 _clock_server=float(value.server_time);_clock_ticks=Time.get_ticks_msec()
 _save_session();changed.emit()

func _pump() -> void:
 busy=true
 var generation := _generation
 var item: Dictionary = _queue.pop_front()
 _inflight_op=str(item.op)
 changed.emit()
 if not await _authenticate():
  if generation==_generation: _queue.push_front(item)
  busy=false
  _retry_at=Time.get_ticks_msec()/1000.0+10
  changed.emit()
  return
 if generation!=_generation: busy=false; return
 var payload := item.duplicate(true)
 payload.merge({"player_id":str(profile.data.identity.id),"player_name":str(profile.data.identity.name),"token":str(profile.data.identity.token)})
 var started := Time.get_ticks_msec()
 var result: Dictionary
 if edge.enabled:
  result=await edge.call_server("command",payload) if await edge.ensure_session(_access) else {"error":edge.last_error if not edge.last_error.is_empty() else "network_error"}
 else:result=await _http("/rest/v1/rpc/lakebound_matches",{"payload":payload},true)
 if generation!=_generation: busy=false; return
 busy=false
 if result.has("error"):
  var reason := str(result.error)
  connected=false
  if reason in ["network_error","busy_retry","rate_limited"]:
   if item.op!="claim_fish" or _claim_waiters.has(str(item.get("_claim_ticket",""))): _queue.push_front(item)
   _retry_count=mini(_retry_count+1,4)
   _retry_at=Time.get_ticks_msec()/1000.0+pow(2,_retry_count)+randf()
  elif reason=="jwt_expired":
   _expires=0
   if account_auth!=null: account_auth.expires_at=0
   _queue.push_front(item)
  elif item.op=="state" and reason in ["not_a_member","room_not_found"]:
   forget_room(false)
  elif item.op=="leave" and reason=="not_a_member":
   forget_room(false)
   return
  _complete_claim(item,result)
  _fail(reason)
  return
 if item.op=="leave" and result.get("schema")==1:
  forget_room(false)
  return
 if not valid_snapshot(result):
  _fail("invalid_response"); return
 if edge.enabled and result.get("id")==room.get("id") and float(result.server_time)<float(room.get("server_time",0)):result=room
 connected=true
 _retry_count=0
 error_message=""
 _clock_server=float(result.server_time)+(Time.get_ticks_msec()-started)/2000.0
 _clock_ticks=Time.get_ticks_msec()
 var old_id := str(room.get("id",""))
 room=result
 _complete_claim(item,result)
 _pending_room=str(room.id)
 if old_id!=str(room.id): realtime.close()
 _save_session()
 if item.op=="leave": forget_room(false)
 else: changed.emit()

func _authenticate() -> bool:
 if base_url.is_empty() or api_key.is_empty(): _fail("not_configured"); return false
 if account_auth==null or not account_auth.signed_in(): _fail("google_login_required"); return false
 if not await account_auth.ensure_session(): _fail("google_login_required"); return false
 if _access!=account_auth.access_token: realtime.close()
 _access=account_auth.access_token
 _expires=account_auth.expires_at
 return true

func _http(path: String, body: Dictionary, authenticated := false) -> Dictionary:
 var headers := PackedStringArray(["Content-Type: application/json","apikey: "+api_key])
 if authenticated: headers.append("Authorization: Bearer "+_access)
 if request.request(base_url+path,headers,HTTPClient.METHOD_POST,JSON.stringify(body))!=OK: return {"error":"network_error"}
 var response: Array = await request.request_completed
 if response[0]!=HTTPRequest.RESULT_SUCCESS or response[3].size()>65536: return {"error":"network_error"}
 var value: Variant = JSON.parse_string(response[3].get_string_from_utf8())
 if response[1]==401 and authenticated: return {"error":"jwt_expired"}
 if not value is Dictionary: return {"error":"invalid_response"}
 if response[1]!=200:
  return {"error":str(value.get("message",value.get("msg","request_failed")))}
 return value

func _save_session() -> void:
 var config := ConfigFile.new()
 config.set_value("session","identity",_identity)
 config.set_value("session","room",_pending_room)
 config.set_value("session","backend","cloudflare" if using_edge() else "supabase")
 config.save(PlayerSavePaths.MATCH_SESSION)

func _fail(reason: String) -> void:
 error_message=reason
 failed.emit(reason)
 changed.emit()

static func valid_room_code(value: String) -> bool:
 if value.length()!=5: return false
 for digit in value:
  if digit<"0" or digit>"9": return false
 return true

static func valid_snapshot(value: Variant) -> bool:
 if not value is Dictionary or value.get("schema")!=1: return false
 for field in ["id","code","host","map","phase","round_id"]:
  if not value.get(field) is String: return false
 if value.phase not in ["lobby","loading","countdown","running","finished","cancelled"]: return false
 if not FishingJournal.known_map(value.map) or value.id.length()!=36 or not valid_room_code(value.code): return false
 if not (value.get("duration") is int or value.get("duration") is float): return false
 var duration := float(value.duration)
 if not is_finite(duration) or duration<180 or duration>1200 or duration!=floorf(duration): return false
 # JSON numbers arrive as floats; Array.has/in distinguishes 600.0 from 600.
 if int(duration) not in MatchRules.DURATIONS: return false
 if value.get("rule") not in MatchRules.MODES+["legacy_top3"] or not value.get("target_species") is String: return false
 if value.rule=="species_total":
  if value.target_species not in MatchRules.species_for(value.map): return false
 elif not value.target_species.is_empty(): return false
 for field in ["server_time","starts_at","ends_at","seed","pose_interval"]:
  if not (value.get(field) is int or value.get(field) is float) or not is_finite(float(value[field])): return false
 if float(value.pose_interval)<0.334 or float(value.pose_interval)>60: return false
 if not (value.get("poll_interval") is int or value.get("poll_interval") is float) or not is_finite(float(value.poll_interval)) or float(value.poll_interval)<5.0 or float(value.poll_interval)>60: return false
 if not value.get("members") is Array or value.members.is_empty() or value.members.size()>10: return false
 if not value.get("fish_claims",[]) is Array or value.get("fish_claims",[]).size()>20: return false
 if not value.get("consumed_fish",[]) is Array or value.get("consumed_fish",[]).size()>1000: return false
 var fish_ids := {}
 for claim in value.get("fish_claims",[]):
  if not claim is Array or claim.size()!=6: return false
  if not (claim[0] is float or claim[0] is int) or not is_finite(float(claim[0])) or float(claim[0])!=floorf(float(claim[0])) or claim[0]<1 or claim[0]>100000: return false
  if fish_ids.has(int(claim[0])): return false
  fish_ids[int(claim[0])]=true
  if not claim[1] is String or not claim[2] is String or claim[1].length()!=32 or claim[2].length()!=36 or not claim[4] is String: return false
  for index in [3,5]:
   if not (claim[index] is int or claim[index] is float) or not is_finite(float(claim[index])) or claim[index]<=0: return false
 for id in value.get("consumed_fish",[]):
  if not (id is int or id is float) or not is_finite(float(id)) or float(id)!=floorf(float(id)) or id<1 or id>100000: return false
 var seen := {}
 for item in value.members:
  if not item is Dictionary: return false
  for field in ["id","name"]:
   if not item.get(field) is String: return false
  if seen.has(item.id): return false
  seen[item.id]=true
  for field in ["ready","loaded","departed","online"]:
   if not item.get(field) is bool: return false
  for field in ["grams","rank"]:
   if not (item.get(field) is float or item.get(field) is int) or not is_finite(float(item[field])) or float(item[field])<0: return false
  if not item.get("best") is Array or item.best.size()>3: return false
 return true
