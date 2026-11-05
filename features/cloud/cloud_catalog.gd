class_name CloudCatalog
extends RefCounted
const PATH := "res://data/cloud/catalog_v1.json"
static var _catalog: Dictionary = {}
static func data() -> Dictionary:
 if _catalog.is_empty():
  var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
  if value is Dictionary: _catalog = value
 return _catalog
static func code(kind: String, value: String) -> int:
 if value.is_empty(): return 0
 var rows: Array = data().get(kind,[])
 return rows.find(value)
static func key(kind: String, value: Variant) -> String:
 if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)): return ""
 var rows: Array = data().get(kind,[])
 var index := int(value)
 return str(rows[index]) if index>0 and index<rows.size() else ""
