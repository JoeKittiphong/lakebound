extends Node
## Persistent background uploads. Local best records are the durable outbox.
signal leader_updated(map_id: String, state: Dictionary)
signal scores_uploaded
signal sync_failed(reason: String)

@export var enabled := true
@export_range(15.0, 300.0, 1.0) var refresh_interval := 60.0
@export_range(1.0, 60.0, 1.0) var retry_base_seconds := 2.0
var profile: AnglerProfile
var sync := RankingSync.new()
var endpoint := ""
var publishable_key := ""
var watched_map := ""
var busy := false
var dirty := false
var retry_attempt := 0
var _fresh_maps := {}
var _last_map := "all"
var _identity := ""
var _name := ""
var _sent_write := false
var _failed := false
var account_auth: Node
@onready var request: HTTPRequest = $Request

func _ready() -> void:
 if OS.has_feature("web"): request.accept_gzip=false
 enabled = enabled and OS.get_environment("LAKEBOUND_BACKGROUND_SYNC") != "0"
 account_auth=get_node_or_null("/root/AccountAuth")
 if account_auth!=null and account_auth.enabled and not account_auth.signed_in(): enabled=false
 sync.save_path = PlayerSavePaths.BACKGROUND_SYNC
 sync.cache_path = PlayerSavePaths.BACKGROUND_CACHE
 var config := ConfigFile.new()
 if config.load("res://online.cfg") == OK:
  endpoint = SupabaseConnectionSettings.resolve(str(config.get_value("supabase", "url", "")))
  publishable_key = str(config.get_value("supabase", "publishable_key", ""))
 request.request_completed.connect(_completed)
 $Retry.timeout.connect(flush)
 $Refresh.timeout.connect(func(): dirty = true; flush())
 bind_profile(get_node_or_null("/root/AnglerSave"))

func bind_profile(value: AnglerProfile) -> void:
 if is_instance_valid(profile):
  if profile.catch_recorded.is_connected(_caught): profile.catch_recorded.disconnect(_caught)
  if profile.changed.is_connected(_profile_changed): profile.changed.disconnect(_profile_changed)
 if busy: request.cancel_request()
 busy = false
 $Retry.stop()
 profile = value
 if profile == null: return
 _identity = str(profile.data.identity.id)
 _name = str(profile.data.identity.name)
 sync.configure(endpoint, _identity)
 profile.catch_recorded.connect(_caught)
 profile.changed.connect(_profile_changed)
 dirty = not profile.ranking_records().is_empty()
 if dirty: flush.call_deferred()

func active_for(value: AnglerProfile) -> bool:
 return enabled and is_instance_valid(profile) and profile == value and SupabaseConnectionSettings.valid_url(endpoint) and not publishable_key.is_empty()

func set_connection(url: String, key: String) -> void:
 if endpoint == url and publishable_key == key: return
 if busy: request.cancel_request()
 busy = false
 endpoint = url
 publishable_key = key
 _fresh_maps.clear()
 sync.configure(endpoint, _identity)
 dirty = true
 flush.call_deferred()

func _profile_changed() -> void:
 if profile == null: return
 var identity := str(profile.data.identity.id)
 var player_name := str(profile.data.identity.name)
 if identity == _identity and player_name == _name: return
 if identity != _identity:
  if busy: request.cancel_request()
  busy = false
  _fresh_maps.clear()
  sync.configure(endpoint, identity)
 _identity = identity
 _name = player_name
 dirty = true
 flush.call_deferred()

func _caught(record: Dictionary) -> void:
 _last_map = str(record.get("map", "all"))
 dirty = true
 # Queue one follow-up when another catch arrives during a request; never build
 # over the in-flight pending signatures that still need acknowledgement.
 flush.call_deferred()

func watch_map(map_id: String) -> void:
 if not FishingJournal.known_map(map_id): return
 watched_map = map_id
 var cloud:=get_node_or_null("/root/CloudSync")
 if enabled and (cloud==null or not cloud.active_for(profile)):$Refresh.start(refresh_interval)
 leader_updated.emit(map_id, leader_state(map_id))
 dirty = true
 flush.call_deferred()

func unwatch_map(map_id: String) -> void:
 if watched_map != map_id: return
 watched_map = ""
 $Refresh.stop()
 var cloud:=get_node_or_null("/root/CloudSync")
 if cloud!=null and cloud.watched_map==map_id:cloud.watched_map=""

func accept_cloud_leader(value: Variant) -> void:
 if not value is Array or value.size()!=3 or not RankingSnapshot.valid_version(value[1]) or not value[2] is Array:return
 var map_id:=CloudCatalog.key("map",value[0])
 if map_id.is_empty():return
 var wire: Array=[]
 if not value[2].is_empty():
  if value[2].size()!=4:return
  var fish:=CloudCatalog.key("fish",value[2][2])
  wire.append([value[2][0],value[2][1],fish,value[2][3]])
 var decoded:=RankingSnapshot.decode(wire,map_id,10)
 if decoded.is_empty():return
 sync.views[map_id+":10"]={"version":value[1],"rows":decoded.rows,"wire":wire,"received_at":Time.get_unix_time_from_system()}
 sync._save_views()
 _fresh_maps[map_id]=true
 leader_updated.emit(map_id,leader_state(map_id))

func leader_state(map_id: String) -> Dictionary:
 var cached := sync.cached_view("map", map_id, 10)
 if cached.is_empty(): return {"loaded": false, "cached": false, "failed": _failed, "record": {}}
 var rows: Array = cached.rows
 return {"loaded": true, "cached": not _fresh_maps.get(map_id, false), "record": rows[0] if not rows.is_empty() else {}}

func flush() -> void:
 if busy or not dirty or not active_for(profile) or profile.incompatible or profile.data.identity.name.is_empty(): return
 var cloud:=get_node_or_null("/root/CloudSync")
 if cloud!=null and cloud.active_for(profile):
  dirty=false
  cloud.request_leader(watched_map if not watched_map.is_empty() else _last_map)
  return
 if account_auth!=null and account_auth.enabled:
  if not account_auth.signed_in(): return
  busy=true
  var identity_before := str(profile.data.identity.id)
  var session_ok: bool=await account_auth.ensure_session()
  busy=false
  if not session_ok or str(profile.data.identity.id)!=identity_before: return
 $Retry.stop()
 dirty = false
 busy = true
 var map_id := watched_map if not watched_map.is_empty() else _last_map
 var payload := sync.build(profile, "all" if map_id == "all" else "map", map_id, 10)
 _sent_write = not sync.read_only
 var error := _send(sync.rpc_body(payload))
 if error != OK: _completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())

func _send(body: String) -> Error:
 var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + publishable_key])
 if account_auth!=null and account_auth.signed_in(): headers.append("Authorization: Bearer "+account_auth.access_token)
 return request.request(endpoint, headers, HTTPClient.METHOD_POST, body)

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
 if not busy: return
 var data: Variant = null
 if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() <= RankingSnapshot.MAX_RESPONSE_BYTES:
  data = JSON.parse_string(body.get_string_from_utf8())
 var response := sync.accept(data) if data is Dictionary else {}
 busy = false
 if response.is_empty():
  _failed = true
  dirty = true
  var reason := str(data.get("error", "invalid_response")) if data is Dictionary else "network_error"
  _fresh_maps.clear()
  if not watched_map.is_empty(): leader_updated.emit(watched_map, leader_state(watched_map))
  sync_failed.emit(reason)
  # Auth/payload errors need a new event/configuration, not an endless retry loop.
  if reason not in ["invalid_credentials", "invalid_payload", "invalid_name", "invalid_catch", "conflicting_catch", "name_required", "invalid_query"] and code not in [400,401,403,409]:
   retry_attempt += 1
   $Retry.start(minf(60.0, retry_base_seconds * pow(2.0, mini(retry_attempt - 1, 5)) * randf_range(0.9, 1.1)))
  return
 retry_attempt = 0
 _failed = false
 if response.has("rows") and sync.query_scope != "all":
  _fresh_maps[sync.query_scope] = true
  leader_updated.emit(sync.query_scope, leader_state(sync.query_scope))
 if _sent_write: scores_uploaded.emit()
 if response.get("upload_only", false): dirty = true
 if dirty: flush.call_deferred()
