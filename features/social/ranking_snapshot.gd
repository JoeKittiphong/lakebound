class_name RankingSnapshot
extends RefCounted
## One boundary for the compact ranking wire format and persisted view cache.
const MAX_GRAMS := 1000000000
const MAX_RESPONSE_BYTES := 262144

static func valid_version(value: Variant) -> bool:
 return value is String and not value.is_empty() and value.length() <= 128

static func decode(wire: Variant, map: String, limit: int) -> Dictionary:
 if limit not in [10, 50, 100] or (map != "all" and not FishingJournal.known_map(map)):
  return {}
 if not wire is Array or wire.size() > limit:
  return {}
 var rows: Array = []
 var players := {}
 var width := 5 if map == "all" else 4
 var previous_grams := MAX_GRAMS
 for row in wire:
  if not row is Array or row.size() != width: return {}
  for column in width - 1:
   if not row[column] is String: return {}
  if not valid_player_id(row[0]) or players.has(row[0]) or not AnglerIdentity.valid_name(row[1]): return {}
  var grams: Variant = row[width - 1]
  if not (grams is float or grams is int): return {}
  if not is_finite(float(grams)) or grams != floorf(float(grams)) or grams <= 0 or grams > previous_grams: return {}
  var species := str(row[3] if width == 5 else row[2])
  var region := str(row[2]) if width == 5 else map
  var fish := FishCatalog.find(StringName(species))
  if fish == null or not FishingJournal.known_map(region): return {}
  players[row[0]] = true
  previous_grams = int(grams)
  rows.append({"rank": rows.size() + 1, "player_id": row[0], "player_name": row[1], "map": region, "species": species, "name": fish.display_name, "weight": float(grams) / 1000.0, "time": 0.0})
 return {"rows": rows}

static func valid_player_id(value: String) -> bool:
 if value.length() != 32: return false
 for character in value:
  if character not in "0123456789abcdef": return false
 return true
