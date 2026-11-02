class_name AnglerProfile
extends Node

signal changed
signal missions_completed(ids: Array[String])
const Catalog = preload("res://data/equipment/tackle_catalog.gd")
const SNAPSHOT_RECORD_CONTAINERS = ["catches", "journal", "boss_history", "ponds", "receipts"]
var save_path := "user://angler_profile_v1.cfg"
var data: Dictionary = {}
var save_error := ""
var incompatible := false

func _ready() -> void:
 load_profile()

func defaults() -> Dictionary:
 return ProfileStore.defaults()

func load_profile() -> void:
 var result := ProfileStore.load_profile(save_path)
 data = result.data
 incompatible = result.incompatible
 save_error = ""
 if incompatible:
  save_error = "ข้อมูลผู้เล่นไม่ถูกต้อง — เก็บไฟล์เดิมไว้" if result.invalid_data else "อ่านข้อมูลผู้เล่นไม่ได้ — เก็บไฟล์เดิมไว้"
 else:
  repair_equipment_fit()
  repair_terminal_rig()

func _valid(value: Variant) -> bool:
 return ProfileStore.valid(value)

func _transaction_snapshot() -> Dictionary:
 # Transactions append/remove records or replace a pond snapshot; they never
 # edit existing history records/population entries in place. Copy their outer
 # containers only. Mutable domains (notably mission entries) stay deep copies.
 if data.journal.is_empty() and data.catches.is_empty() and data.boss_history.is_empty() and data.ponds.is_empty():
  return data.duplicate(true)
 var before := data.duplicate()
 for key in data:
  if data[key] is Array or data[key] is Dictionary:
   before[key] = data[key].duplicate(key not in SNAPSHOT_RECORD_CONTAINERS)
 return before

func _commit(before: Dictionary) -> bool:
 if incompatible:
  data = before
  return false
 var error := ProfileStore.save_profile(save_path, data)
 if error != OK:
  data = before
  save_error = "บันทึกไม่สำเร็จ — ยกเลิกรายการแล้ว"
  changed.emit()
  return false
 save_error = ""
 changed.emit()
 return true

func equipped(slot: String) -> Resource:
 return Catalog.item(str(data.equipped.get(slot, "")))

func equipment_name(slot: String) -> String:
 var item := equipped(slot)
 return item.display_name if item != null else "ยังไม่ได้ใส่"

func spare_line_count(id: String) -> int:
 return int(data.spares.get(id, 0)) + data.get("stored_lines", {}).get(id, []).size()

func _detach_line() -> void:
 var line := equipped("line")
 if line != null and data.line_remaining > 0:
  var id := str(line.id)
  if not data.stored_lines.has(id): data.stored_lines[id] = []
  data.stored_lines[id].append(float(data.line_remaining))
 data.equipped.line = ""
 data.line_remaining = 0.0

func _clear_rod_components() -> void:
 _detach_line()
 data.equipped.reel = ""
 data.equipped.bait = ""
 data.terminal_rig = ""

func unequip(slot: String) -> bool:
 if incompatible or not data.pending.is_empty() or slot not in ["rod", "reel", "line", "bait", "box"] or equipped(slot) == null:
  return false
 if slot == "box" and box_weight() > 0:
  save_error = "นำปลาออกจากกล่องก่อนถอดกล่อง"
  return false
 var before := _transaction_snapshot()
 if slot == "rod": _clear_rod_components()
 if slot == "line": _detach_line()
 data.equipped[slot] = ""
 if slot == "bait": data.terminal_rig = ""
 return _commit(before)

func reel_for_rod(rod: Resource) -> Resource:
 var current := equipped("reel")
 if EquipmentFit.compatible(rod, current) and quantity(str(current.id)) > 0: return current
 for entry in Catalog.ITEMS:
  if entry.kind == "reel" and quantity(str(entry.id)) > 0 and EquipmentFit.compatible(rod, entry): return entry
 return null

func equipment_fit_error(entry: Resource) -> String:
 if entry == null: return "ไม่พบอุปกรณ์"
 if entry.kind == "rod": return ""
 if entry.kind in ["reel", "line", "bait", "lure"] and equipped("rod") == null:
  return "เลือกคันเบ็ดก่อน"
 if entry.kind == "reel" and not EquipmentFit.compatible(equipped("rod"), entry):
  return "คันที่เลือกใช้%s" % EquipmentFit.layout_label(equipped("rod").mount_layout)
 if entry.kind in ["bait", "lure"]:
  return _result_error(candidate_rig_result(entry))
 if entry.kind == "line":
  return line_fit_error(entry)
 return ""

func line_fit_error(entry: TackleItem) -> String:
 var spec := entry.line_spec
 if spec == null: return "สายยังไม่มีสเปกครบ"
 if not is_finite(spec.diameter_mm) or spec.diameter_mm <= 0 or not is_finite(spec.break_kgf) or spec.break_kgf <= 0:
  return "สเปกสายไม่ถูกต้อง"
 var rod: TackleItem = equipped("rod")
 if rod == null: return "เลือกคันเบ็ดก่อน"
 if rod.mount_layout == "fixed":
  return "ชุดนี้ไม่ใช้สายฟลาย" if spec.material == "fly" and rod.rod_spec.family != "tenkara" else ""
 var reel: TackleItem = equipped("reel")
 if reel == null: return "เลือกรอกก่อนใส่สาย"
 if reel.reel_spec == null: return "รอกยังไม่มีสเปกครบ"
 if (spec.material == "fly") != (reel.reel_family == "fly"): return "สายฟลายต้องใช้กับชุดฟลายเท่านั้น"
 if spec.material == "fly":
  return "หมายเลขสายฟลายไม่ตรงกับคันและรอก" if spec.fly_weight != rod.rod_spec.fly_weight or spec.fly_weight < reel.reel_spec.fly_weight_min or spec.fly_weight > reel.reel_spec.fly_weight_max else ""
 if spec.diameter_mm < reel.reel_spec.diameter_min_mm or spec.diameter_mm > reel.reel_spec.diameter_max_mm:
  return "ขนาดสาย %.2f mm ไม่อยู่ในช่วงรอก %.2f–%.2f mm" % [spec.diameter_mm, reel.reel_spec.diameter_min_mm, reel.reel_spec.diameter_max_mm]
 return ""

static func _result_error(result: Dictionary) -> String:
 return "" if result.allowed else " · ".join(result.reasons)

func current_rig() -> TerminalRigSpec:
 var bait: TackleItem = equipped("bait")
 if bait == null: return null
 for rig in bait.terminal_rigs:
  if str(rig.id) == str(data.get("terminal_rig", "")): return rig
 return bait.terminal_rigs[0] if not bait.terminal_rigs.is_empty() else null

func rig_result(rig: TerminalRigSpec = null) -> Dictionary:
 return RigCompatibility.evaluate(equipped("rod"), equipped("reel"), equipped("line"), equipped("bait"), current_rig() if rig == null else rig)

func candidate_rig_result(bait: TackleItem) -> Dictionary:
 var chosen: TerminalRigSpec = null
 for rig in bait.terminal_rigs:
  if str(rig.id) == str(data.get("terminal_rig", "")):
   var existing := RigCompatibility.evaluate(equipped("rod"), equipped("reel"), equipped("line"), bait, rig)
   if existing.allowed: return existing
 for rig in bait.terminal_rigs:
  if chosen == null: chosen = rig
  var test := RigCompatibility.evaluate(equipped("rod"), equipped("reel"), equipped("line"), bait, rig)
  if test.allowed: return test
 return RigCompatibility.evaluate(equipped("rod"), equipped("reel"), equipped("line"), bait, chosen)

func repair_terminal_rig() -> void:
 # Legacy migration resolves rig only; it never buys, consumes or changes bait.
 var bait: TackleItem = equipped("bait")
 if bait == null:
  data.terminal_rig = ""
  return
 for rig in bait.terminal_rigs:
  if str(rig.id) == str(data.get("terminal_rig", "")): return
 var candidate := candidate_rig_result(bait)
 if candidate.allowed:
  data.terminal_rig = candidate.rig_id
  return
 data.terminal_rig = str(bait.terminal_rigs[0].id) if not bait.terminal_rigs.is_empty() else ""

func select_rig(id: String) -> bool:
 if incompatible or not data.pending.is_empty(): return false
 if equipped("bait") == null: return false
 for rig in equipped("bait").terminal_rigs:
  if str(rig.id) != id: continue
  var result := rig_result(rig)
  if not result.allowed:
   save_error = _result_error(result)
   return false
  var before := _transaction_snapshot()
  data.terminal_rig = id
  return _commit(before)
 return false

func line_capacity() -> float:
 var rod: TackleItem = equipped("rod")
 if rod == null or equipped("line") == null: return 0.0
 if rod.mount_layout == "fixed": return minf(equipped("line").length, rod.rod_spec.length_m * 1.15)
 var reel: TackleItem = equipped("reel")
 var line: TackleItem = equipped("line")
 if reel == null or reel.reel_spec == null or line.line_spec == null: return 0.0
 return minf(reel.length, reel.reel_spec.capacity_for(line.line_spec.diameter_mm))

func repair_equipment_fit() -> bool:
 var rod := equipped("rod")
 # Empty slots are intentional saved state, never auto-fill or switch the rod.
 if rod == null or equipped("reel") == null: return true
 if rod.mount_layout == "fixed" or EquipmentFit.compatible(rod, equipped("reel")): return true
 var reel := reel_for_rod(rod)
 if reel != null:
  data.equipped.reel = str(reel.id)
  return true
 # Old saves remain readable. Reuse owned equipment; never grant or purchase gear.
 for entry in Catalog.ITEMS:
  if entry.kind == "rod" and quantity(str(entry.id)) > 0 and EquipmentFit.compatible(entry, equipped("reel")):
   data.equipped.rod = str(entry.id)
   return true
 return false

func current_fit_error() -> String:
 var rod := equipped("rod")
 for slot in ["rod", "line", "bait"]:
  if equipped(slot) == null: return "ชุดยังไม่ครบ — เลือกคัน รอก สาย และเหยื่อในกระเป๋า"
 if rod.mount_layout != "fixed" and equipped("reel") == null: return "ชุดยังไม่ครบ — เลือกรอกก่อนตกปลา"
 if rod.mount_layout != "fixed" and not EquipmentFit.compatible(rod, equipped("reel")):
  return "คันกับรอกไม่เข้าคู่ — เปิดกระเป๋าเพื่อเลือกชุดอุปกรณ์"
 return _result_error(rig_result())

func set_catch_note(catch_id: String, text: String) -> bool:
 if text.length() > 240 or not FishingJournal.has_catch(data.journal, catch_id):
  return false
 var before := _transaction_snapshot()
 if text.strip_edges().is_empty():
  data.map_memory.notes.erase(catch_id)
 else:
  data.map_memory.notes[catch_id] = text.strip_edges()
 return _commit(before)

func add_fishing_spot(map: String, point: Vector2, from_boat: bool = false) -> bool:
 if not FishingJournal.valid_point(point) or not FishingJournal.known_map(map):
  return false
 for spot in data.map_memory.favorites:
  if spot.map == map and spot.from_boat == from_boat and spot.position.distance_squared_to(point) <= 1.0:
   return true
 if data.map_memory.favorites.size() >= 200:
  return false
 var before := _transaction_snapshot()
 var number: int = data.map_memory.next_spot
 data.map_memory.next_spot += 1
 data.map_memory.favorites.append({"id": Crypto.new().generate_random_bytes(16).hex_encode(),
  "map": map, "position": point, "from_boat": from_boat, "name": "จุดตกปลา #%d" % number})
 return _commit(before)

func remove_fishing_spot(id: String) -> bool:
 var before := _transaction_snapshot()
 for index in data.map_memory.favorites.size():
  if data.map_memory.favorites[index].id == id:
   data.map_memory.favorites.remove_at(index)
   return _commit(before)
 return false

func quantity(id: String) -> int:
 return int(data.stock.get(id, 0))

## Explicit playtest grant: does not spend currency, equip gear or settle lost lures.
func grant_trial_equipment() -> bool:
 if incompatible or not data.pending.is_empty():
  return false
 var before := _transaction_snapshot()
 for entry in Catalog.ITEMS:
  var id := String(entry.id)
  if entry.kind == "line":
   data.spares[id] = maxi(int(data.spares.get(id, 0)), 3)
  else:
   data.stock[id] = maxi(quantity(id), 30 if entry.kind == "bait" else 1)
 return _commit(before)

func buy(id: String) -> bool:
 var entry := Catalog.item(id)
 if entry == null or data.coins < entry.price:
  return false
 if entry.kind not in ["bait", "lure", "line"] and quantity(id) > 0:
  return false
 var before := _transaction_snapshot()
 data.coins -= entry.price
 if entry.kind == "line":
  data.spares[id] = int(data.spares.get(id, 0)) + 1
 else:
  data.stock[id] = quantity(id) + entry.quantity
 return _commit(before)

func equip(id: String) -> bool:
 var entry := Catalog.item(id)
 if entry == null or not data.pending.is_empty():
  return false
 if entry.kind == "box" and box_weight() > entry.capacity:
  return false
 var fit_error := equipment_fit_error(entry)
 if not fit_error.is_empty():
  save_error = fit_error
  return false
 var before := _transaction_snapshot()
 if entry.kind == "line":
  var replacing_active := equipped("line") == entry
  if replacing_active and int(data.spares.get(id, 0)) <= 0: return false
  if spare_line_count(id) <= 0:
   return false
  _detach_line()
  if replacing_active:
   data.spares[id] -= 1
   data.line_remaining = entry.length
  elif not data.stored_lines.get(id, []).is_empty():
   data.line_remaining = float(data.stored_lines[id].pop_front())
  else:
   data.spares[id] -= 1
   data.line_remaining = entry.length
 elif quantity(id) <= 0:
  return false
 if entry.kind == "rod" and str(data.equipped.rod) != id:
  _clear_rod_components()
 data.equipped[entry.kind] = id
 if entry.kind in ["bait", "lure"]:
  data.equipped.bait = id
  # A bait selection chooses a compatible preset but never changes rod/reel/line.
  data.terminal_rig = str(candidate_rig_result(entry).rig_id)
 return _commit(before)

func prepare_cast() -> bool:
 if incompatible or not data.pending.is_empty() or data.line_remaining < 1.0:
  return false
 var fit_error := current_fit_error()
 if not fit_error.is_empty():
  save_error = fit_error
  return false
 var bait := equipped("bait")
 if quantity(String(bait.id)) <= 0:
  return false
 if bait.kind == "lure":
  return true
 var before := _transaction_snapshot()
 data.stock[String(bait.id)] -= 1
 return _commit(before)

func break_line(deployed: float, lure_id: String) -> bool:
 if not is_finite(deployed) or deployed < 0 or not data.pending.is_empty():
  return false
 var before := _transaction_snapshot()
 data.line_remaining = maxf(0.0, data.line_remaining - deployed)
 var entry := Catalog.item(lure_id)
 if entry != null and entry.kind == "lure" and quantity(lure_id) > 0:
  data.stock[lure_id] -= 1
  data.pending = {"id": "%d-%d" % [Time.get_unix_time_from_system() * 1000, Time.get_ticks_usec()], "lure": lure_id, "cost": entry.recovery_cost}
 return _commit(before)

func recover_with_diamonds() -> bool:
 if data.pending.is_empty() or data.diamonds < int(data.pending.cost):
  return false
 var before := _transaction_snapshot()
 data.diamonds -= int(data.pending.cost)
 var id: String = data.pending.lure
 data.stock[id] = quantity(id) + 1
 data.pending = {}
 return _commit(before)

# Only the trusted provider handles earned rewards/verified purchase receipts.
# The game UI cannot mint diamonds or claim an ad was watched.
func apply_verified_reward(receipt: String, recovery_id: String) -> bool:
 if receipt.is_empty() or receipt in data.receipts or data.pending.is_empty() or str(data.pending.id) != recovery_id:
  return false
 var before := _transaction_snapshot()
 var id: String = data.pending.lure
 data.stock[id] = quantity(id) + 1
 data.pending = {}
 data.receipts.append(receipt)
 return _commit(before)

func apply_verified_purchase(receipt: String, amount: int) -> bool:
 if receipt.is_empty() or amount <= 0 or receipt in data.receipts:
  return false
 var before := _transaction_snapshot()
 data.diamonds += amount
 data.receipts.append(receipt)
 return _commit(before)

func discard_lure() -> bool:
 if data.pending.is_empty():
  return false
 var before := _transaction_snapshot()
 data.pending = {}
 return _commit(before)

func box_weight() -> float:
 var total := 0.0
 for record in data.catches:
  total += float(record.weight)
 return total

func keep_catch(record: Dictionary, map_id: String = "", population: Array = []) -> bool:
 if equipped("box") == null or not record.has("weight") or not is_finite(float(record.weight)) or record.weight <= 0 or box_weight() + record.weight > equipped("box").capacity:
  return false
 var before := _transaction_snapshot()
 data.catches.append(record.duplicate(true))
 if not map_id.is_empty():
  data.ponds[map_id] = population
 return _commit(before)

func sell_catches() -> bool:
 if data.catches.is_empty():
  return false
 var before := _transaction_snapshot()
 for record in data.catches:
  data.coins += maxi(1, int(round(float(record.weight) * 35.0)))
 data.catches = []
 return _commit(before)

## The expected record prevents stale UI selection from disposing another fish.
## Restored population data is committed with the storage change in one save.
func dispose_stored_catch(index: int, expected: Dictionary, sell: bool, return_population: Array = []) -> bool:
 if index < 0 or index >= data.catches.size() or data.catches[index] != expected:
  return false
 if not sell and return_population.is_empty():
  return false
 var before := _transaction_snapshot()
 var record: Dictionary = data.catches[index]
 if sell:
  data.coins += maxi(1, int(round(float(record.weight) * 35.0)))
 elif not return_population.is_empty():
  data.ponds[str(record.map)] = return_population
 data.catches.remove_at(index)
 return _commit(before)

func record_catch(record: Dictionary, boss: bool, track_collection: bool = true) -> bool:
 # Gameplay supplies a stable event token; repeated delivery is a no-op.
 var before := _transaction_snapshot()
 CatchArchive.prepare(data)
 if CatchArchive.contains(data, str(record.get("catch_id", ""))):
  return true
 data.journal.append(record.duplicate(true))
 CatchArchive.remember(data.history, record)
 if track_collection:
  data.history.pending.append(record.duplicate(true))
 if boss:
  data.boss_history.append(record.duplicate(true))
  data.history.boss_counts[str(record.map)] = int(data.history.boss_counts.get(str(record.map), 0)) + 1
 CatchArchive.compact(data)
 var event := record.duplicate(true)
 event["boss"] = boss
 var completed: Array[String] = []
 if event.get("mission_eligible", true):
  completed = MissionProgress.apply_catch(data.missions, event)
 if not _commit(before):
  return false
 if not completed.is_empty():
  missions_completed.emit(completed)
 return true

func finish_catch_history(collection: Node) -> bool:
 var before := _transaction_snapshot()
 CatchArchive.prepare(data)
 if collection.recording_enabled:
  for species in collection.records:
   if int(collection.records[species].count) > int(data.history.stats.get(species, {}).get("count", 0)):
    data.history.stats[species] = collection.records[species].duplicate()
 data.history.pending = []
 CatchArchive.compact(data)
 if data == before:
  return true
 return _commit(before)

func ranking_records() -> Array:
 CatchArchive.prepare(data)
 return data.history.map_bests.values()

func lifetime_catches() -> int:
 CatchArchive.prepare(data)
 var count := 0
 for stats in data.history.stats.values(): count += int(stats.count)
 return count

func start_missions() -> bool:
 if data.missions.started:
  return true
 var before := _transaction_snapshot()
 data.missions.started = true
 data.missions.tracked = "first_three"
 return _commit(before)

func track_mission(id: String) -> bool:
 if not data.missions.started or (not id.is_empty() and MissionCatalog.find(id) == null):
  return false
 var before := _transaction_snapshot()
 data.missions.tracked = id
 return _commit(before)

func claim_mission(id: String) -> bool:
 var definition := MissionCatalog.find(id)
 if definition == null or not data.missions.started:
  return false
 var value := MissionProgress.entry(data.missions, definition)
 if value.claimed or value.progress < definition.target:
  return false
 var before := _transaction_snapshot()
 value.claimed = true
 data.missions.entries[id] = value
 data.coins += definition.reward_coins
 if data.missions.tracked == id:
  data.missions.tracked = ""
 return _commit(before)

func store_pond(map_id: String, records: Array, population_revision: String="") -> bool:
 var before := _transaction_snapshot()
 data.ponds[map_id] = records
 if not population_revision.is_empty():data.pond_revisions[map_id]=population_revision
 return _commit(before)

func emergency_supplies() -> bool:
 # Free play must remain possible after a series of mistakes. This cannot be
 # sold, exchanged for diamonds or used to bypass a pending recovery decision.
 if data.coins >= 20 or not data.catches.is_empty() or not data.pending.is_empty():
  return false
 if quantity("worm") + quantity("dough") > 0 and data.line_remaining >= 1.0:
  return false
 var before := _transaction_snapshot()
 data.stock.worm = maxi(quantity("worm"), 3)
 data.equipped.bait = "worm"
 if data.line_remaining < 1.0:
  data.equipped.line = "fine_line"
  data.line_remaining = 15.0
 repair_terminal_rig()
 return _commit(before)

func set_display_name(value: String) -> bool:
 var text := value.strip_edges()
 if not AnglerIdentity.valid_name(text):
  return false
 var before := _transaction_snapshot()
 data.identity.name = text
 return _commit(before)
