class_name FishingMethods
extends RefCounted

static func grouped(journal: Array, map_id: String) -> Array:
 var groups := {}
 for record in journal:
  if str(record.get("map","")) != map_id:
   continue
  var id := str(record.get("species",""))
  if not groups.has(id):
   groups[id] = {"species":id,"name":str(record.get("name",id)),"records":[],"best":0.0}
  groups[id].records.append(record)
  groups[id].best = maxf(groups[id].best,float(record.get("weight",0)))
 var result: Array = groups.values()
 result.sort_custom(func(a: Dictionary,b: Dictionary): return a.name < b.name)
 for group in result:
  group.records.sort_custom(func(a: Dictionary,b: Dictionary): return float(a.get("time",0)) > float(b.get("time",0)))
 return result

static func gear_name(record: Dictionary, key: String) -> String:
 var value := str(record.get(key+"_id",record.get(key,"")))
 if value.is_empty(): return "ไม่ได้บันทึก"
 var item := TackleCatalog.item(value)
 return str(item.display_name if item != null else value).get_slice(" ×",0)

static func setting(record: Dictionary,key: String,unit: String) -> String:
 var settings: Variant = record.get("settings",{})
 if not settings is Dictionary: return "ไม่ได้บันทึก"
 var value: Variant = settings.get(key)
 if not (value is float or value is int) or not is_finite(float(value)): return "ไม่ได้บันทึก"
 return ("%d%%" % roundi(float(value)*100)) if unit == "%" else "%.1f %s" % [float(value),unit]
