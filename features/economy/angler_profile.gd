class_name AnglerProfile
extends Node

signal changed
signal missions_completed(ids: Array[String])
const Catalog = preload("res://data/equipment/tackle_catalog.gd")
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

func _valid(value: Variant) -> bool:
 return ProfileStore.valid(value)

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
 return Catalog.item(str(data.equipped[slot]))

func quantity(id: String) -> int:
 return int(data.stock.get(id, 0))

func buy(id: String) -> bool:
 var entry := Catalog.item(id)
 if entry == null or data.coins < entry.price:
  return false
 if entry.kind not in ["bait", "lure", "line"] and quantity(id) > 0:
  return false
 var before := data.duplicate(true)
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
 var before := data.duplicate(true)
 if entry.kind == "line":
  if int(data.spares.get(id, 0)) <= 0:
   return false
  data.spares[id] -= 1
  data.line_remaining = entry.length
 elif quantity(id) <= 0:
  return false
 data.equipped[entry.kind] = id
 if entry.kind in ["bait", "lure"]:
  data.equipped.bait = id
 return _commit(before)

func prepare_cast() -> bool:
 if incompatible or not data.pending.is_empty() or data.line_remaining < 1.0:
  return false
 var bait := equipped("bait")
 if quantity(String(bait.id)) <= 0:
  return false
 if bait.kind == "lure":
  return true
 var before := data.duplicate(true)
 data.stock[String(bait.id)] -= 1
 return _commit(before)

func break_line(deployed: float, lure_id: String) -> bool:
 if not is_finite(deployed) or deployed < 0 or not data.pending.is_empty():
  return false
 var before := data.duplicate(true)
 data.line_remaining = maxf(0.0, data.line_remaining - deployed)
 var entry := Catalog.item(lure_id)
 if entry != null and entry.kind == "lure" and quantity(lure_id) > 0:
  data.stock[lure_id] -= 1
  data.pending = {"id": "%d-%d" % [Time.get_unix_time_from_system() * 1000, Time.get_ticks_usec()], "lure": lure_id, "cost": entry.recovery_cost}
 return _commit(before)

func recover_with_diamonds() -> bool:
 if data.pending.is_empty() or data.diamonds < int(data.pending.cost):
  return false
 var before := data.duplicate(true)
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
 var before := data.duplicate(true)
 var id: String = data.pending.lure
 data.stock[id] = quantity(id) + 1
 data.pending = {}
 data.receipts.append(receipt)
 return _commit(before)

func apply_verified_purchase(receipt: String, amount: int) -> bool:
 if receipt.is_empty() or amount <= 0 or receipt in data.receipts:
  return false
 var before := data.duplicate(true)
 data.diamonds += amount
 data.receipts.append(receipt)
 return _commit(before)

func discard_lure() -> bool:
 if data.pending.is_empty():
  return false
 var before := data.duplicate(true)
 data.pending = {}
 return _commit(before)

func box_weight() -> float:
 var total := 0.0
 for record in data.catches:
  total += float(record.weight)
 return total

func keep_catch(record: Dictionary, map_id: String = "", population: Array = []) -> bool:
 if not record.has("weight") or not is_finite(float(record.weight)) or record.weight <= 0 or box_weight() + record.weight > equipped("box").capacity:
  return false
 var before := data.duplicate(true)
 data.catches.append(record.duplicate(true))
 if not map_id.is_empty():
  data.ponds[map_id] = population
 return _commit(before)

func sell_catches() -> bool:
 if data.catches.is_empty():
  return false
 var before := data.duplicate(true)
 for record in data.catches:
  data.coins += maxi(1, int(round(float(record.weight) * 35.0)))
 data.catches = []
 return _commit(before)

func record_catch(record: Dictionary, boss: bool) -> bool:
 # Gameplay supplies a stable event token; repeated delivery is a no-op.
 if not str(record.get("catch_id", "")).is_empty():
  for previous in data.journal:
   if previous.get("catch_id", "") == record.catch_id:
    return true
 var before := data.duplicate(true)
 data.journal.append(record.duplicate(true))
 if boss:
  data.boss_history.append(record.duplicate(true))
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

func start_missions() -> bool:
 if data.missions.started:
  return true
 var before := data.duplicate(true)
 data.missions.started = true
 data.missions.tracked = "first_three"
 return _commit(before)

func track_mission(id: String) -> bool:
 if not data.missions.started or (not id.is_empty() and MissionCatalog.find(id) == null):
  return false
 var before := data.duplicate(true)
 data.missions.tracked = id
 return _commit(before)

func claim_mission(id: String) -> bool:
 var definition := MissionCatalog.find(id)
 if definition == null or not data.missions.started:
  return false
 var value := MissionProgress.entry(data.missions, definition)
 if value.claimed or value.progress < definition.target:
  return false
 var before := data.duplicate(true)
 value.claimed = true
 data.missions.entries[id] = value
 data.coins += definition.reward_coins
 if data.missions.tracked == id:
  data.missions.tracked = ""
 return _commit(before)

func store_pond(map_id: String, records: Array) -> bool:
 var before := data.duplicate(true)
 data.ponds[map_id] = records
 return _commit(before)

func emergency_supplies() -> bool:
 # Free play must remain possible after a series of mistakes. This cannot be
 # sold, exchanged for diamonds or used to bypass a pending recovery decision.
 if data.coins >= 20 or not data.catches.is_empty() or not data.pending.is_empty():
  return false
 if quantity("worm") + quantity("dough") > 0 and data.line_remaining >= 1.0:
  return false
 var before := data.duplicate(true)
 data.stock.worm = maxi(quantity("worm"), 3)
 data.equipped.bait = "worm"
 if data.line_remaining < 1.0:
  data.equipped.line = "fine_line"
  data.line_remaining = 15.0
 return _commit(before)
