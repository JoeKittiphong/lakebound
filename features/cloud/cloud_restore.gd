class_name CloudRestore
extends RefCounted

static func record(row: Variant) -> Dictionary:
 if not row is Array or row.size()!=11:return {}
 var map_id := CloudCatalog.key("map",row[1])
 var species := CloudCatalog.key("fish",row[2])
 var fish := FishCatalog.find(StringName(species))
 var bait := CloudCatalog.key("item",row[6])
 if map_id.is_empty() or fish==null or bait.is_empty() or not row[7] is Array or row[7].size()!=4:return {}
 var result := {"catch_id":str(row[0]),"map":map_id,"species":species,"name":fish.display_name,"weight":float(row[3])/1000.0,"time":float(row[4])/1000.0,"depth":float(row[5])/100.0,"bait_id":bait,"fish_key":map_id+":"+str(row[8]),"boss":(int(row[9])&1)!=0,"mission_eligible":(int(row[9])&2)!=0}
 var bait_item := TackleCatalog.item(bait)
 if bait_item==null:return {}
 result.bait_kind=bait_item.kind
 result.bait=bait_item.display_name
 for index in 3:
  var key := CloudCatalog.key("item",row[7][index])
  var item := TackleCatalog.item(key)
  result[["rod","reel","line"][index]]=item.display_name if item!=null else "ยังไม่ได้ใส่"
 if row[10]!=null:
  if not row[10] is Array or row[10].size()!=5:return {}
  result.location={"angler_xz":Vector2(float(row[10][0]),float(row[10][1]))/100.0,"bite_xz":Vector2(float(row[10][2]),float(row[10][3]))/100.0,"from_boat":bool(row[10][4])}
 return result

static func assemble(local: Dictionary, rows: Array, replace_all := true) -> Dictionary:
 # Construct and validate a candidate first. Never mutate the last good save.
 var data := ProfileStore.defaults() if replace_all else local.duplicate(true)
 data.identity=local.identity.duplicate(true)
 data.cloud=local.cloud.duplicate(true)
 data.ponds=local.ponds.duplicate(true)
 data.pond_revisions=local.pond_revisions.duplicate(true)
 data.travel=local.get("travel",{}).duplicate(true)
 if replace_all:data.stock={};data.spares={};data.stored_lines={}
 data.history.initialized=true
 var journal := {}
 if not replace_all:
  for caught in local.journal+local.catches:journal[str(caught.catch_id)]=caught
 var box: Array=[]
 var cleared := {}
 for row in rows:
  if not row is Array or row.size()!=3 or not row[0] is String:return {}
  var domain: String=row[0]
  var key := str(row[1])
  var value: Variant=row[2]
  if row[1]==null and value==null:
   if domain in ["i","sp","sl"]:data[{"i":"stock","sp":"spares","sl":"stored_lines"}[domain]]={}
   elif domain=="s":data.map_memory.favorites=[]
   elif domain=="a":data.map_memory.notes={}
   elif domain=="me":data.missions.entries={}
   elif domain=="b":data.catches=[]
   else:return {}
   cleared[domain]=true
   continue
  if not replace_all and not cleared.has(domain):
   if domain in ["i","sp","sl"]:data[{"i":"stock","sp":"spares","sl":"stored_lines"}[domain]]={}
   if domain=="s":data.map_memory.favorites=[]
   if domain=="a":data.map_memory.notes={}
   if domain=="me":data.missions.entries={}
   cleared[domain]=true
  match domain:
   "w":
    if not value is Array or value.size()!=2:return {}
    data.coins=int(value[0]);data.diamonds=int(value[1])
   "i","sp":
    var id := CloudCatalog.key("item",int(key))
    if id.is_empty() or float(value)!=floorf(float(value)) or float(value)<0:return {}
    data["stock" if domain=="i" else "spares"][id]=int(value)
   "sl":
    var id := CloudCatalog.key("item",int(key))
    if id.is_empty() or not value is Array:return {}
    data.stored_lines[id]=value.map(func(cm: Variant):return float(cm)/100.0)
   "e":
    if key not in data.equipped:return {}
    data.equipped[key]=CloudCatalog.key("item",value)
   "t":data.terminal_rig=CloudCatalog.key("rig",value)
   "ln":data.line_remaining=float(value)/100.0
   "b":box.append(key)
   "p":
    if not value is Dictionary:return {}
    data.pending=value.duplicate(true)
    if not data.pending.is_empty():
     data.pending.lure=CloudCatalog.key("item",data.pending.lure)
     data.pending.cost=int(data.pending.cost)
   "m":
    if key=="s":data.missions.started=bool(value)
    elif key=="t":data.missions.tracked=CloudCatalog.key("mission",value)
    else:return {}
   "me":
    var id := CloudCatalog.key("mission",int(key))
    if id.is_empty() or not value is Array or value.size()!=5:return {}
    data.missions.entries[id]={"revision":int(value[0]),"progress":float(value[1]),"claimed":bool(value[2]),"seen":value[3],"unique":value[4]}
   "s":
    if not value is Array or value.size()!=5:return {}
    data.map_memory.favorites.append({"id":key,"map":CloudCatalog.key("map",value[0]),"position":Vector2(float(value[1]),float(value[2]))/100.0,"from_boat":bool(value[3]),"name":str(value[4])})
   "a":data.map_memory.notes[key]=str(value)
   "nx":data.map_memory.next_spot=int(value)
   "n":data.identity.name=str(value) if not str(value).is_empty() else data.identity.name
   "h":
    var id := CloudCatalog.key("fish",row[1])
    if id.is_empty() or not value is Array or value.size()!=5:return {}
    data.history.stats[id]={"count":int(value[0]),"total":float(value[1])/1000.0,"best":float(value[2])/1000.0,"smallest":float(value[3])/1000.0,"last":float(value[4])/1000.0}
   "j","k":
    var caught := record(value)
    if caught.is_empty():return {}
    if domain=="j":journal[caught.catch_id]=caught
    else:data.history.map_bests[key]={"catch_id":caught.catch_id,"map":caught.map,"species":caught.species,"name":caught.name,"weight":caught.weight,"time":caught.time}
   "bc":data.history.boss_counts[key]=int(value)
   _:return {}
 if replace_all:data.journal=CatchArchive.top(journal.values())
 if not replace_all and cleared.has("b"):data.catches=[]
 for id in box:
  if not journal.has(id):return {}
  data.catches.append(journal[id])
 data.boss_history=data.journal.filter(func(c: Dictionary):return bool(c.get("boss",false)))
 if replace_all:data.history.recent_ids=journal.keys().slice(-128)
 for id in data.map_memory.notes.keys():
  if not FishingJournal.has_catch(data.journal,id):data.map_memory.notes.erase(id)
 data.cloud.restored=true
 return data if ProfileStore.valid(data) else {}

static func delta_rows(delta: Dictionary) -> Array:
 var rows: Array=[]
 for domain in delta:
  var value: Variant=delta[domain]
  if domain in ["i","sp","sl","e","s","a"]:
   if not value is Dictionary:return []
   if domain!="e":rows.append([domain,null,null])
   for key in value:rows.append([domain,key,value[key]])
  elif domain=="m":
   if not value is Dictionary:return []
   rows.append(["m","s",value.get("s",false)])
   rows.append(["m","t",value.get("t",0)])
   rows.append(["me",null,null])
   for key in value.get("e",{}):rows.append(["me",key,value.e[key]])
  elif domain=="h":
   if not value is Array:return []
   for entry in value:
    if not entry is Array or entry.size()!=6:return []
    rows.append(["h",entry[0],entry.slice(1)])
  elif domain=="b":
   if not value is Array:return []
   rows.append(["b",null,null])
   for id in value:rows.append(["b",id,true])
  elif domain in ["w","t","ln","p","nx","n"]:rows.append([domain,"",value])
 return rows
