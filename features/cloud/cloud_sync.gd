extends Node
signal changed
signal failed(reason: String)
@export var enabled := false
@export_range(15.0,300.0,1.0) var refresh_seconds := 60.0
var profile: AnglerProfile
var account_auth: Node
var busy := false
var status := "ยังไม่เปิด Cloud Save"
var endpoint := ""
var api_key := ""
var account_id := ""
var dirty := false
var watched_map := ""
var _applying := false
var _generation := 0
var _retry := 0
var _response: Array=[]
@onready var request: HTTPRequest=$Request

func _ready() -> void:
 if OS.has_feature("web"): request.accept_gzip=false
 var config:=ConfigFile.new()
 if config.load("res://online.cfg")==OK:
  enabled=bool(config.get_value("cloud","enabled",enabled)) and OS.get_environment("LAKEBOUND_CLOUD")!="0"
  endpoint=str(config.get_value("supabase","url","")).get_slice("/rest/",0)+"/rest/v1/rpc/lakebound_sync"
  api_key=str(config.get_value("supabase","publishable_key",""))
 account_auth=get_node_or_null("/root/AccountAuth")
 request.request_completed.connect(func(result: int,code: int,headers: PackedStringArray,body: PackedByteArray):_response=[result,code,headers,body])
 $Retry.timeout.connect(flush)
 $Refresh.timeout.connect(func():dirty=true;flush())
 if account_auth!=null:account_auth.authenticated.connect(_authenticated)
 bind_profile(get_node_or_null("/root/AnglerSave"),"offline")

func _authenticated() -> void:
 if account_auth!=null:bind_profile(get_node_or_null("/root/AnglerSave"),str(account_auth.user_id))

func bind_profile(value: AnglerProfile,account: String) -> void:
 _generation+=1
 if busy:request.cancel_request()
 busy=false
 $Retry.stop();$Refresh.stop()
 if is_instance_valid(profile) and profile.changed.is_connected(_profile_changed):profile.changed.disconnect(_profile_changed)
 profile=value;account_id=account
 if profile==null:return
 profile.changed.connect(_profile_changed)
 if not enabled or account=="offline":return
 if account.length()!=36 or not profile.data.cloud.owner.is_empty() and profile.data.cloud.owner!=account:
  _fail("account_mismatch");return
 if profile.data.cloud.owner.is_empty():
  var defaults:=profile.defaults()
  if profile.lifetime_catches()>0 or profile.data.coins!=defaults.coins or profile.data.diamonds!=0 or profile.data.stock!=defaults.stock or not profile.data.catches.is_empty() or not profile.data.map_memory.favorites.is_empty():
   _fail("existing_save_requires_review");return
  var before:=profile._transaction_snapshot()
  profile.data.cloud=profile.data.cloud.duplicate(true)
  profile.data.cloud.owner=account;profile.data.cloud.tracking=true
  _applying=true
  var saved:=profile._commit(before,[],false)
  _applying=false
  if not saved:_fail("save_failed");return
 dirty=true
 $Refresh.start(refresh_seconds)
 flush.call_deferred()

func active_for(value: AnglerProfile) -> bool:
 return enabled and is_instance_valid(value) and value==profile and account_id!="offline" and profile.data.cloud.owner==account_id and profile.data.cloud.tracking

func _profile_changed() -> void:
 if _applying or not active_for(profile):return
 if not profile.data.cloud.events.is_empty():dirty=true;flush.call_deferred()

func request_leader(map_id: String) -> void:
 if FishingJournal.known_map(map_id):watched_map=map_id
 dirty=true
 flush.call_deferred()

func flush() -> void:
 if busy or not dirty or not active_for(profile) or profile.incompatible:return
 if account_auth==null or not account_auth.signed_in() or str(account_auth.user_id)!=account_id:return
 busy=true;dirty=false
 var generation:=_generation
 if not await account_auth.ensure_session():
  if generation==_generation:busy=false;_schedule_retry("session_unavailable")
  return
 if generation!=_generation:return
 var leader_version: String=str(profile.data.cloud.remote.get("leader",[0,""])[1]) if profile.data.cloud.remote.has("leader") and int(profile.data.cloud.remote.leader[0])==CloudCatalog.code("map",watched_map) else ""
 var packet:=CloudOutbox.packet(profile.data.cloud,CloudCatalog.code("map",watched_map),leader_version)
 var response: Variant=await _http(packet)
 if generation!=_generation:return
 if response is Dictionary:
  busy=false;_schedule_retry(str(response.get("error","network_error")));return
 var updated:=CloudOutbox.accept(profile.data.cloud,response,packet)
 if updated.is_empty():busy=false;_schedule_retry("invalid_response");return
 var delta: Dictionary=response[3] if response.size()==4 else {}
 updated.needs_restore=bool(updated.get("needs_restore",true)) or delta.get("resync",false) or delta.has("reject")
 var before:=profile._transaction_snapshot()
 profile.data.cloud=updated
 _applying=true
 var saved:=profile._commit(before,[],false)
 _applying=false
 if not saved:busy=false;_schedule_retry("save_failed");return
 if delta.has("leader"):
  var ranking:=get_node_or_null("/root/RankingOnline")
  if ranking!=null:ranking.accept_cloud_leader(delta.leader)
 if not profile.data.cloud.events.is_empty():
  dirty=true
 elif not profile.data.cloud.restored or profile.data.cloud.get("needs_restore",true):
  if not await _restore(generation):
   if generation==_generation:busy=false;_schedule_retry("restore_failed")
   return
 else:
  var rows:=CloudRestore.delta_rows(profile.data.cloud.remote)
  if not rows.is_empty():
   var candidate:=CloudRestore.assemble(profile.data,rows,false)
   if candidate.is_empty():busy=false;_schedule_retry("invalid_delta");return
   if not _apply(candidate):busy=false;_schedule_retry("save_failed");return
 if generation!=_generation:return
 busy=false;_retry=0
 status="สำรองข้อมูลแล้ว" if profile.data.cloud.events.is_empty() else "กำลังส่งข้อมูลที่ค้าง"
 changed.emit()
 var ranking:=get_node_or_null("/root/RankingOnline")
 if ranking!=null:ranking.scores_uploaded.emit()
 if dirty:flush.call_deferred()

func _http(packet: Dictionary) -> Variant:
 var headers:=PackedStringArray(["Content-Type: application/json","apikey: "+api_key,"Authorization: Bearer "+str(account_auth.access_token)])
 var body:=JSON.stringify(packet)
 if body.to_utf8_buffer().size()>32768:return {"error":"payload_too_large"}
 var generation:=_generation
 _response=[]
 if request.request(endpoint,headers,HTTPClient.METHOD_POST,body)!=OK:return {"error":"network_error"}
 while _response.is_empty() and generation==_generation:await get_tree().process_frame
 if generation!=_generation:return {"error":"cancelled"}
 var result: Array=_response
 if result[0]!=HTTPRequest.RESULT_SUCCESS or result[1]!=200 or result[3].size()>32768:return {"error":"network_error"}
 var value: Variant=JSON.parse_string(result[3].get_string_from_utf8())
 return value if value is Array or value is Dictionary else {"error":"invalid_response"}

func _restore(generation: int) -> bool:
 var meta: Dictionary=profile.data.cloud
 var response: Variant=await _http({"p":{"v":2,"c":1,"d":meta.device,"g":[0,-1]}})
 if generation!=_generation or not response is Array or response.size()!=4 or not response[3] is Dictionary or not response[3].get("cp") is Array:return false
 var manifest: Array=response[3].cp
 if manifest.size()!=2 or int(manifest[1])<1 or int(manifest[1])>10000:return false
 var rows: Array=[]
 for page in int(manifest[1]):
  response=await _http({"p":{"v":2,"c":1,"d":meta.device,"g":[manifest[0],page]}})
  if generation!=_generation or not response is Array or response.size()!=4 or not response[3] is Dictionary or not response[3].get("page") is Array:return false
  var body: Array=response[3].page
  if body.size()!=3 or body[0]!=manifest[0] or body[1]!=page or not body[2] is Array:return false
  rows.append_array(body[2])
  if rows.size()>100000:return false
 if not profile.data.cloud.events.is_empty():dirty=true;return true
 var candidate:=CloudRestore.assemble(profile.data,rows)
 if candidate.is_empty():return false
 candidate.cloud.revision=int(manifest[0])
 return _apply(candidate)

func _apply(candidate: Dictionary) -> bool:
 var before:=profile._transaction_snapshot()
 candidate.cloud.collection_pending=true
 candidate.cloud.needs_restore=false
 profile.data=candidate
 _applying=true
 var saved:=profile._commit(before,[],false)
 if saved:
  var collection:=get_node_or_null("/root/FishCollection")
  if collection!=null:saved=CatchSettlement.repair_cloud_collection(profile,collection)
 _applying=false
 return saved

func _schedule_retry(reason: String) -> void:
 dirty=true;_fail(reason)
 if reason in ["cloud_not_enabled","google_login_required","account_not_ready","account_mismatch","existing_save_requires_review","catalog_version","sequence_gap","conflicting_event","invalid_payload"]:return
 _retry+=1
 $Retry.start(minf(60.0,pow(2.0,mini(_retry,5))*randf_range(0.9,1.1)))

func _fail(reason: String) -> void:
 status=reason
 failed.emit(reason)
 changed.emit()
