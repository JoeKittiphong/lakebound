extends Node

signal changed
const Catalog = preload("res://data/fish/fish_catalog.gd")
const SPECIES = Catalog.SPECIES
var save_path := PlayerSavePaths.COLLECTION
var records: Dictionary = {}
var save_error := ""
var recording_enabled := true
var incompatible_save := false

func _ready() -> void:
 load_records()

func stats(id: StringName) -> Dictionary:
 return records.get(String(id), {"count": 0, "total": 0.0, "best": 0.0, "smallest": 0.0, "last": 0.0}).duplicate()

func record_catch(fish: RefCounted) -> String:
 var outcome := record_catch_result(fish)
 return catch_message(outcome)

static func catch_message(outcome: Dictionary) -> String:
 if outcome.is_empty():
  return ""
 if outcome.new_species:
  return "ค้นพบปลาชนิดใหม่!"
 if outcome.new_record:
  return "สถิติน้ำหนักใหม่!"
 return "บันทึกลงสมุดสะสมแล้ว"

func record_catch_result(fish: RefCounted) -> Dictionary:
 if not recording_enabled or fish == null or fish.species == null or not is_finite(fish.weight) or fish.weight <= 0:
  return {}
 var entry := stats(fish.species.id)
 var outcome := {"new_species": entry.count == 0, "new_record": fish.weight > entry.best}
 entry.smallest = fish.weight if entry.count == 0 else minf(entry.smallest, fish.weight)
 entry.count += 1
 entry.total += fish.weight
 entry.best = maxf(entry.best, fish.weight)
 entry.last = fish.weight
 records[String(fish.species.id)] = entry
 outcome.saved = save_records()
 changed.emit()
 return outcome

func save_records() -> bool:
 if incompatible_save:
  return false
 var error := CollectionStore.save_records(save_path, records)
 save_error = "" if error == OK else "บันทึกไม่สำเร็จ สถิติยังอยู่ในรอบนี้"
 return error == OK

func load_records() -> void:
 var result := CollectionStore.load_records(save_path)
 records = result.records
 incompatible_save = result.incompatible
 save_error = "" if result.error == OK else "อ่านสมุดสะสมเดิมไม่สำเร็จ"
