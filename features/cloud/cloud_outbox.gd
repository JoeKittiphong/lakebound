class_name CloudOutbox
extends RefCounted
const MAX_EVENTS := 20000
const MAX_BYTES := 8388608
const MAX_BATCH := 64
const BATCH_BYTES := 16384
const LIMIT := 9007199254740991

static func defaults() -> Dictionary:
 return {"v":2,"owner":"","tracking":false,"device":Crypto.new().generate_random_bytes(8).hex_encode(),"next":1,"ack":0,"revision":0,"events":[],"contexts":{},"context_next":1,"remote":{},"restored":false,"collection_pending":false,"needs_restore":true}

static func valid(state: Variant) -> bool:
 if not state is Dictionary or state.get("v")!=2 or not state.get("events") is Array: return false
 for field in ["next","ack","revision","context_next"]:
  if not state.get(field) is int or state[field]<0 or state[field]>LIMIT: return false
 if state.next<=state.ack or not state.get("tracking") is bool or not state.get("restored") is bool: return false
 if not state.get("owner") is String or not state.get("device") is String or state.device.length()!=16: return false
 for ch in state.device:
  if ch not in "0123456789abcdef": return false
 if not state.get("contexts") is Dictionary or not state.get("remote") is Dictionary or state.events.size()>MAX_EVENTS: return false
 var previous: int = state.ack
 for event in state.events:
  if not event is Array or event.size()!=3 or not event[0] is int or event[0]!=previous+1 or event[1] not in ["f","o"] or not event[2] is Array: return false
  previous=event[0]
 return state.next==previous+1

static func _push(state: Dictionary, kind: String, row: Array) -> void:
 state.events.append([state.next,kind,row])
 state.next+=1

static func _item_map(values: Dictionary) -> Dictionary:
 var result := {}
 for key in values:
  var code := CloudCatalog.code("item",str(values[key]))
  if code<0: return {}
  result[str(key)]=code
 return result

static func capture(before: Dictionary, after: Dictionary, hint: Array = []) -> bool:
 if not after.cloud.tracking: return true
 var state: Dictionary = after.cloud.duplicate()
 state.events=state.events.duplicate()
 state.contexts=state.contexts.duplicate()
 if not hint.is_empty():
  if hint[0]==1:
   var record: Dictionary=hint[1]
   var gear := [CloudCatalog.code("item",str(after.equipped.rod)),CloudCatalog.code("item",str(after.equipped.reel)),CloudCatalog.code("item",str(after.equipped.line)),CloudCatalog.code("rig",str(after.terminal_rig))]
   var signature := JSON.stringify(gear)
   if not state.contexts.has(signature):
    state.contexts[signature]=state.context_next
    _push(state,"o",[9,state.context_next,gear])
    state.context_next+=1
   var location: Variant=null
   if record.has("location"):
    location=[roundi(record.location.angler_xz.x*100),roundi(record.location.angler_xz.y*100),roundi(record.location.bite_xz.x*100),roundi(record.location.bite_xz.y*100),int(record.location.from_boat)]
   var flags := int(record.get("boss",false))+2*int(record.get("mission_eligible",true))
   # Preserve the original catch ID for local journal/collection/match consistency.
   var row := [CloudCatalog.code("map",str(record.map)),CloudCatalog.code("fish",str(record.species)),AnglerIdentity.grams(record),roundi(float(record.time)*1000),roundi(float(record.depth)*100),CloudCatalog.code("item",str(record.get("bait_id",after.equipped.bait))),state.contexts[signature],str(record.get("fish_key",record.catch_id)).trim_prefix(str(record.map)+":"),flags,location,str(record.catch_id)]
   if row[0]<1 or row[1]<1 or row[5]<1: return false
   _push(state,"f",row)
  else: _push(state,"o",hint.duplicate(true))
 for id in before.map_memory.notes:
  if not after.map_memory.notes.has(id): _push(state,"o",[10,id,""])
 for id in after.map_memory.notes:
  if before.map_memory.notes.get(id)!=after.map_memory.notes[id]: _push(state,"o",[10,id,after.map_memory.notes[id]])
 var old_spots := {}
 for spot in before.map_memory.favorites: old_spots[spot.id]=spot
 var new_spots := {}
 for spot in after.map_memory.favorites:
  new_spots[spot.id]=spot
  if old_spots.get(spot.id)!=spot:
   _push(state,"o",[11,spot.id,CloudCatalog.code("map",spot.map),roundi(spot.position.x*100),roundi(spot.position.y*100),int(spot.from_boat),spot.name,after.map_memory.next_spot])
 for id in old_spots:
  if not new_spots.has(id): _push(state,"o",[12,id])
 if before.missions.started!=after.missions.started or before.missions.tracked!=after.missions.tracked:
  _push(state,"o",[8,int(after.missions.started),CloudCatalog.code("mission",str(after.missions.tracked))])
 if before.identity.name!=after.identity.name: _push(state,"o",[19,str(after.identity.name)])
 if hint.is_empty() and (before.equipped!=after.equipped or before.terminal_rig!=after.terminal_rig):
  _push(state,"o",[13,_item_map(after.equipped),CloudCatalog.code("rig",str(after.terminal_rig))])
 if state.events.size()>MAX_EVENTS or JSON.stringify(state.events).to_utf8_buffer().size()>MAX_BYTES: return false
 after.cloud=state
 return valid(state)

static func packet(state: Dictionary, leader_map := 0, leader_version := "") -> Dictionary:
 var payload := {"v":2,"c":1,"r":state.revision,"d":state.device}
 var base_time := 0
 var included := 0
 for event in state.events:
  var field := str(event[1])
  if not payload.has(field): payload[field]=[]
  var row: Array=event[2].duplicate(true)
  if field=="f":
   if base_time==0: base_time=int(row[3]);payload["t"]=base_time
   row[3]=int(row[3])-base_time
  row.push_front(event[0])
  payload[field].append(row)
  if JSON.stringify({"p":payload}).to_utf8_buffer().size()>BATCH_BYTES:
   payload[field].pop_back()
   if payload[field].is_empty():payload.erase(field)
   break
  included+=1
  if included>=MAX_BATCH:break
 if leader_map>0:payload["l"]=[leader_map,leader_version]
 return {"p":payload}

static func accept(state: Dictionary, response: Variant, sent: Dictionary) -> Dictionary:
 if not response is Array or response.size()<3 or response.size()>4 or response[0]!=2:return {}
 for index in [1,2]:
  if not (response[index] is int or response[index] is float) or not is_finite(float(response[index])) or float(response[index])!=floorf(float(response[index])):return {}
 var revision := int(response[1])
 var ack := int(response[2])
 var sent_max: int=state.ack
 for field in ["f","o"]:
  for row in sent.p.get(field,[]):sent_max=maxi(sent_max,int(row[0]))
 if revision<state.revision or revision>LIMIT or ack<state.ack or ack>sent_max:return {}
 if response.size()==4 and not response[3] is Dictionary:return {}
 var updated := state.duplicate(true)
 updated.revision=revision
 updated.ack=ack
 updated.events=updated.events.filter(func(row: Array):return row[0]>ack)
 if response.size()==4:updated.remote.merge(response[3],true)
 return updated if valid(updated) else {}
