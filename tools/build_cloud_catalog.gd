extends SceneTree
## Append-only wire IDs. Existing positions are never sorted, deleted or reused.
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var path := "res://data/cloud/catalog_v1.json"
 var catalog: Dictionary = {"v":1,"map":[""],"fish":[""],"item":[""],"mission":[""],"rig":[""],"defs":{"item":{},"mission":{}}}
 if FileAccess.file_exists(path): catalog = JSON.parse_string(FileAccess.get_file_as_string(path))
 var groups := {"map":[],"fish":[],"item":[],"mission":[],"rig":[]}
 for entry in RegionCatalog.MAPS: groups.map.append(str(entry.id))
 for fish in FishCatalog.ALL_SPECIES: groups.fish.append(str(fish.id))
 for item in TackleCatalog.ITEMS:
  groups.item.append(str(item.id))
  for rig in item.terminal_rigs:
   if str(rig.id) not in groups.rig: groups.rig.append(str(rig.id))
 for mission in MissionCatalog.ALL_ITEMS: groups.mission.append(str(mission.id))
 for kind in groups:
  groups[kind].sort()
  for key in groups[kind]:
   if key not in catalog[kind]: catalog[kind].append(key)
 for item in TackleCatalog.ITEMS:
  catalog.defs.item[str(catalog.item.find(str(item.id)))]={"id":str(item.id),"price":item.price,"quantity":item.quantity,"kind":item.kind,"recovery":item.recovery_cost,"capacity_g":roundi(item.capacity*1000),"length_cm":roundi(item.length*100)}
 for mission in MissionCatalog.ALL_ITEMS:
  catalog.defs.mission[str(catalog.mission.find(str(mission.id)))]={"id":str(mission.id),"revision":mission.revision,"metric":mission.metric,"target":mission.target,"map":str(mission.map_id),"species":str(mission.species_id),"bait":str(mission.bait_id),"kind":mission.bait_kind,"min_g":roundi(mission.minimum_weight*1000),"min_depth":roundi(mission.depth_range.x*100),"max_depth":roundi(mission.depth_range.y*100),"boss":mission.boss_only,"reward":mission.reward_coins}
 DirAccess.make_dir_recursive_absolute("res://data/cloud")
 var file := FileAccess.open(path,FileAccess.WRITE)
 file.store_string(JSON.stringify(catalog," ",true)+"\n")
 print("CLOUD CATALOG RESULT: ",catalog.fish.size()-1," fish, ",catalog.item.size()-1," items, ",catalog.mission.size()-1," missions")
 quit()
