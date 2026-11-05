class_name RankingSync
extends RefCounted
## Local acknowledgements are written only after a successful board request.
var save_path := PlayerSavePaths.RANKING_SYNC
var cache_path := PlayerSavePaths.RANKING_CACHE
var endpoint := ""
var player := ""
var acknowledged := {}
var acknowledged_name := ""
var pending := {}
var pending_name := ""
var views := {}
var view_key := ""
var query_scope := "all"
var more := false
var read_only := false

static func is_endpoint(url: String) -> bool:
 return SupabaseConnectionSettings.valid_url(url)

func rpc_body(payload: Dictionary) -> String:
 # A public view must never transmit a guest ID, token, or unregistered name.
 var data := {"query": payload.query} if read_only else payload
 return JSON.stringify({"payload": data})

func build_read(scope: String, filter: String, limit: int) -> Dictionary:
 pending.clear()
 more = false
 read_only = true
 query_scope = filter if scope == "map" else "all"
 view_key = query_scope + ":" + str(limit)
 var query := {"scope": query_scope, "limit": limit}
 if views.has(view_key): query["version"] = views[view_key].version
 return {"query": query}

func configure(url: String, identity: String) -> void:
 if endpoint == url and player == identity: return
 endpoint = url
 player = identity
 acknowledged = {}
 acknowledged_name = ""
 pending.clear()
 pending_name = ""
 more = false
 read_only = false
 views.clear()
 _load_views()
 var config := ConfigFile.new()
 if config.load(save_path) != OK: return
 if config.get_value("sync","endpoint","") != url or config.get_value("sync","player","") != identity: return
 var saved: Variant = config.get_value("sync","bests",{})
 if saved is Dictionary and saved.size() <= 1000:
  for key in saved:
   if key is String and saved[key] is String:
    acknowledged[key] = saved[key]
 acknowledged_name = str(config.get_value("sync","name",""))

func build(profile: AnglerProfile, scope: String, filter: String, limit: int) -> Dictionary:
 configure(endpoint, str(profile.data.identity.id))
 pending.clear()
 pending_name = str(profile.data.identity.name)
 query_scope = filter if scope == "map" else "all"
 view_key = query_scope + ":" + str(limit)
 var catches: Array = []
 more = false
 for record in profile.ranking_records():
  var key := str(record.map) + ":" + str(record.species)
  var row := [record.map,record.species,AnglerIdentity.grams(record),floorf(float(record.time)*1000.0)/1000.0,str(record.catch_id)]
  var signature := JSON.stringify(row)
  if acknowledged.get(key,"") == signature: continue
  if catches.size() >= 100:
   more = true
   continue
  catches.append(row)
  pending[key] = signature
 var payload := {"player_id":profile.data.identity.id,"token":profile.data.identity.token,"catches":catches}
 if acknowledged_name != pending_name: payload["player_name"] = pending_name
 if not more:
  var query := {"scope":query_scope,"limit":limit}
  if views.has(view_key): query["version"] = views[view_key].version
  payload["query"] = query
 # Public rankings do not need guest registration. Delay registration until
 # there is a first real score to upload; a name alone must not slow first view.
 read_only = catches.is_empty() and (acknowledged_name == pending_name or acknowledged.is_empty())
 return payload

func accept(response: Dictionary) -> Dictionary:
 if response.has("error"): return {}
 if more:
  if response.get("ok") != true: return {}
  if not _acknowledge(): return {}
  return {"upload_only":true}
 if not RankingSnapshot.valid_version(response.get("version")): return {}
 var rows: Array = []
 if response.has("not_modified") and not response.not_modified is bool: return {}
 if response.get("not_modified",false):
  if not views.has(view_key) or views[view_key].version != response.version: return {}
  rows = views[view_key].rows
 else:
  if response.get("schema") != 3: return {}
  var decoded := RankingSnapshot.decode(response.get("rows"), query_scope, int(view_key.get_slice(":",1)))
  if decoded.is_empty(): return {}
  rows = decoded.rows
  var changed: bool = not views.has(view_key) or views[view_key].version != response.version
  views[view_key] = {"version":response.version,"rows":rows,"wire":response.rows.duplicate(true),"received_at":Time.get_unix_time_from_system()}
  if changed: _save_views()
 _acknowledge()
 return {"rows":rows}

func cached_view(scope: String, filter: String, limit: int) -> Dictionary:
 var prefix := (filter if scope == "map" else "all") + ":"
 var candidate := ""
 for key in views:
  if not str(key).begins_with(prefix): continue
  if key == prefix+str(limit): candidate=key; break
  if candidate.is_empty() or int(str(key).get_slice(":",1)) > int(candidate.get_slice(":",1)): candidate=key
 if candidate.is_empty(): return {}
 return {"rows":views[candidate].rows.slice(0,limit),"cached":true}

func _save_views() -> void:
 var best := {}
 for key in views:
  var map := str(key).get_slice(":",0)
  var limit := int(str(key).get_slice(":",1))
  if not best.has(map) or limit > int(str(best[map]).get_slice(":",1)): best[map]=key
 var saved := {}
 for key in best.values():
  var entry: Dictionary=views[key]
  if not entry.has("wire"): continue
  saved[key]={"version":entry.version,"rows":entry.wire,"received_at":entry.get("received_at",0.0)}
 var config:=ConfigFile.new()
 config.set_value("cache","endpoint",endpoint)
 config.set_value("cache","player",player)
 config.set_value("cache","views",saved)
 AtomicConfig.save(config,cache_path)

func _load_views() -> void:
 var config:=ConfigFile.new()
 if config.load(cache_path)!=OK or config.get_value("cache","endpoint","")!=endpoint or config.get_value("cache","player","")!=player: return
 var saved: Variant=config.get_value("cache","views",{})
 if not saved is Dictionary or saved.size()>7: return
 for key in saved:
  if not key is String or key.get_slice_count(":") != 2 or not saved[key] is Dictionary: continue
  var map: String=key.get_slice(":",0)
  var limit:=int(key.get_slice(":",1))
  if (map!="all" and not FishingJournal.known_map(map)) or limit not in [10,50,100]: continue
  var entry: Dictionary=saved[key]
  if key != map + ":" + str(limit) or not RankingSnapshot.valid_version(entry.get("version")): continue
  var decoded := RankingSnapshot.decode(entry.get("rows"), map, limit)
  if not decoded.is_empty(): views[key]={"version":entry.version,"rows":decoded.rows,"wire":entry.rows,"received_at":entry.get("received_at",0.0)}

func _acknowledge() -> bool:
 if read_only: return true
 var bests := acknowledged.duplicate()
 bests.merge(pending,true)
 if bests == acknowledged and acknowledged_name == pending_name: return true
 var config := ConfigFile.new()
 config.set_value("sync","endpoint",endpoint)
 config.set_value("sync","player",player)
 config.set_value("sync","bests",bests)
 config.set_value("sync","name",pending_name)
 if AtomicConfig.save(config,save_path) == OK:
  acknowledged = bests
  acknowledged_name = pending_name
  return true
 return false
