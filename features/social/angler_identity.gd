class_name AnglerIdentity
extends RefCounted

static func create() -> Dictionary:
 return {"id": Crypto.new().generate_random_bytes(16).hex_encode(), "name": "", "token": Crypto.new().generate_random_bytes(32).hex_encode()}

static func valid_name(value: String) -> bool:
 var text := value.strip_edges()
 if text.length() < 2 or text.length() > 24:
  return false
 for character in text:
  if character.unicode_at(0) < 32 or character in ["<", ">", "[", "]"]:
   return false
 return true

static func valid(value: Variant) -> bool:
 return value is Dictionary and value.get("id") is String and value.id.length() == 32 and value.get("token") is String and value.token.length() == 64 and value.get("name") is String and (value.name.is_empty() or valid_name(value.name))

static func best(records: Array, scope: String = "all", filter: String = "") -> Array:
 var winners := {}
 for record in records:
  if scope != "all" and str(record.get(scope, "")) != filter:
   continue
  var id := str(record.get("player_id", "local"))
  if not winners.has(id) or grams(record) > grams(winners[id]) or (grams(record) == grams(winners[id]) and float(record.time) < float(winners[id].time)):
   winners[id] = record
 var result: Array = winners.values()
 result.sort_custom(func(a: Dictionary, b: Dictionary):
  if grams(a) != grams(b): return grams(a) > grams(b)
  if float(a.time) != float(b.time): return float(a.time) < float(b.time)
  return str(a.get("player_id", "")) < str(b.get("player_id", "")))
 return result

static func grams(record: Dictionary) -> int:
 return maxi(1, roundi(float(record.weight) * 1000.0))
