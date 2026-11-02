class_name FishingMapPanel
extends Control
signal opened
signal closed
signal target_changed(value: Dictionary)
signal spots_changed(spots: Array)
const PAGE_SIZE := 100
var profile: AnglerProfile
var player: AnglerPlayer
var ecosystem: PondEcosystem
var boss_info: Dictionary = {}
var session_map := "river"
var map_id := "river"
var species := ""
var records: Array = []
var selected: Dictionary = {}
var page := 0
var target: Dictionary = {}
@onready var view: FishingMapView = %MapView
@onready var regions: OptionButton = %Regions
@onready var species_filter: OptionButton = %Species
@onready var history_list: ItemList = %History

func _ready() -> void:
 for region in RegionCatalog.MAPS:
  regions.add_item(region.name)
 regions.item_selected.connect(_region_selected)
 species_filter.item_selected.connect(_species_selected)
 view.selected.connect(_select)
 history_list.item_selected.connect(_history_selected)
 %Close.pressed.connect(close)
 %ZoomIn.pressed.connect(func(): view.set_zoom(view.zoom + 0.5))
 %ZoomOut.pressed.connect(func(): view.set_zoom(view.zoom - 0.5))
 %ResetView.pressed.connect(view.reset_view)
 %Navigate.pressed.connect(_navigate)
 %Favorite.pressed.connect(_favorite)
 %SaveNote.pressed.connect(_save_note)
 %Here.pressed.connect(_save_here)
 %ClearTarget.pressed.connect(func(): target = {}; view.target = {}; target_changed.emit({}); view.queue_redraw())
 %Previous.pressed.connect(func(): page -= 1; _fill_history())
 %Next.pressed.connect(func(): page += 1; _fill_history())

func bind(value: AnglerProfile, actor: AnglerPlayer, region: String, source: PondEcosystem = null) -> void:
 profile = value
 player = actor
 ecosystem = source
 session_map = region
 map_id = region
 _emit_spots()

func open(filter_species: String = "", preferred_map: String = "") -> void:
 if profile == null:
  return
 species = filter_species
 map_id = preferred_map if FishingJournal.known_map(preferred_map) else session_map
 # A collection shortcut may refer to a catch from another region.
 if preferred_map.is_empty() and not species.is_empty() and FishingJournal.history(profile.data.journal, map_id, species).is_empty():
  for record in profile.data.journal:
   if record.species == species and FishingJournal.known_map(record.map):
    map_id = record.map
    break
 selected = {}
 page = 0
 %Notice.text = "ประวัติการจับของคุณ · ปลาเคลื่อนที่ได้ตามธรรมชาติ"
 _configure_region()
 show()
 opened.emit()

func close() -> void:
 if not visible:
  return
 hide()
 closed.emit()

func _input(event: InputEvent) -> void:
 if visible and event.is_action_pressed("ui_cancel"):
  close()
  get_viewport().set_input_as_handled()

func _configure_region() -> void:
 for index in RegionCatalog.MAPS.size():
  if RegionCatalog.MAPS[index].id == map_id:
   regions.select(index)
 view.configure(FishingMapDefinition.for_region(map_id))
 view.show_player = map_id == session_map
 if is_instance_valid(player):
  view.player_position = Vector2(player.global_position.x, player.global_position.z)
  view.player_yaw = player.visual.global_rotation.y
 view.target = target if map_id == session_map else {}
 species_filter.clear()
 species_filter.add_item("ปลาทั้งหมด")
 species_filter.set_item_metadata(0, "")
 var found := {}
 for record in profile.data.journal:
  if record.map != map_id or found.has(record.species):
   continue
  found[record.species] = true
  var index := species_filter.item_count
  species_filter.add_item(record.name)
  species_filter.set_item_metadata(index, record.species)
  if record.species == species:
   species_filter.select(index)
 if not found.has(species):
  species = ""
 _refresh()

func _region_selected(index: int) -> void:
 map_id = RegionCatalog.MAPS[index].id
 species = ""
 page = 0
 selected = {}
 _configure_region()

func _species_selected(index: int) -> void:
 species = species_filter.get_item_metadata(index)
 page = 0
 selected = {}
 _refresh()

func _spots(region: String) -> Array:
 var result: Array = []
 if profile != null:
  for spot in profile.data.map_memory.favorites:
   if spot.map == region:
    result.append(spot)
 return result

func _emit_spots() -> void:
 spots_changed.emit(_spots(session_map))

func _refresh() -> void:
 _refresh_boss()
 records = FishingJournal.history(profile.data.journal, map_id, species)
 view.set_history(records, _spots(map_id))
 view.selection = selected
 _fill_history()
 _show_details()
 %Here.disabled = map_id != session_map or profile.incompatible

func _refresh_boss() -> void:
 boss_info = {}
 var population: Array = []
 var live := map_id == session_map and is_instance_valid(ecosystem)
 if live:
  population = ecosystem.snapshot()
 else:
  population = profile.data.ponds.get(map_id, [])
 for fish in population:
  if boss_info.is_empty() or float(fish.weight) > float(boss_info.weight):
   boss_info = fish.duplicate(true)
 view.boss = {}
 CatchArchive.prepare(profile.data)
 var victories: int = profile.data.history.boss_counts.get(map_id, 0)
 if boss_info.is_empty():
  %BossName.text = "ยังไม่มีจ้าวบ่อ" if live else "ยังไม่มีข้อมูลแหล่งน้ำนี้"
  %BossStats.text = "พิชิตแล้ว %d ครั้ง" % victories
  return
 var definition := FishCatalog.find(StringName(boss_info.species))
 var collection := get_node("/root/FishCollection")
 var discovered: bool = collection.stats(StringName(boss_info.species)).count > 0
 var display_name: String = definition.display_name if discovered and definition != null else "???"
 %BossName.text = "%s · %.2f กก." % [display_name, boss_info.weight]
 %BossStats.text = "พิชิตแล้ว %d ครั้ง · %s" % [victories, "ตำแหน่งปัจจุบัน" if live else "ข้อมูลที่บันทึกไว้"]
 boss_info["display_name"] = display_name
 boss_info["victories"] = victories
 boss_info["live"] = live
 var boss_position: Vector3 = boss_info.position
 view.boss = {"position": Vector2(boss_position.x, boss_position.z)}

func _fill_history() -> void:
 page = clampi(page, 0, maxi(0, floori((records.size() - 1) / float(PAGE_SIZE))))
 history_list.clear()
 var start := page * PAGE_SIZE
 for index in range(start, mini(start + PAGE_SIZE, records.size())):
  var record: Dictionary = records[index]
  history_list.add_item("%s · %.2f กก.%s" % [record.name, record.weight, "" if record.has("location") else " · ไม่มีพิกัด"])
 %Count.text = "ยังไม่มีประวัติในพื้นที่นี้\nจับปลาแล้วเกมจะบันทึกให้อัตโนมัติ" if records.is_empty() else "ประวัติ %d ครั้ง · หน้า %d / %d" % [records.size(), page+1, maxi(1, ceili(records.size()/float(PAGE_SIZE)))]
 %Previous.disabled = page == 0
 %Next.disabled = start + PAGE_SIZE >= records.size()

func _history_selected(index: int) -> void:
 _select({"kind": "catch", "record": records[page * PAGE_SIZE + index]})

func _select(value: Dictionary) -> void:
 selected = value
 view.selection = value
 if value.get("kind") == "catch":
  var index := records.find(value.record)
  if index >= 0:
   page = floori(index / float(PAGE_SIZE))
   _fill_history()
   history_list.select(index % PAGE_SIZE)
   history_list.ensure_current_is_visible()
 _show_details()
 view.queue_redraw()

func _show_details() -> void:
 var kind: String = selected.get("kind", "")
 %NoteRow.visible = not str(selected.record.get("catch_id", "")).is_empty() if kind == "catch" else false
 %SaveNote.disabled = profile.incompatible
 %Navigate.text = "กลับไปจุดยืนนี้" if kind == "catch" else "ไปยังจุดที่เลือก"
 %Navigate.disabled = true
 %Favorite.disabled = true
 %Favorite.text = "เพิ่มจุดโปรด"
 %DetailTitle.text = "เลือกจุดบนแผนที่"
 %Detail.text = "แตะประวัติเพื่อดูจุดยืนและจุดปลากินเหยื่อ\nหรือแตะพื้นที่เพื่อบันทึกจุดโปรด"
 if kind == "catch":
  var record: Dictionary = selected.record
  %DetailTitle.text = "%s · %.2f กก." % [record.name, record.weight]
  var date := Time.get_datetime_dict_from_unix_time(int(record.time) + int(Time.get_time_zone_from_system().bias) * 60)
  var location: Dictionary = record.get("location", {})
  %Detail.text = "%s · ลึก %.1f ม.\n%02d/%02d/%04d · %02d:%02d\n%s" % [record.bait, record.depth, date.day, date.month, date.year, date.hour, date.minute,
   ("ตกจากเรือ · ใช้เรือกลับไปยังจุดนี้" if location.get("from_boat", false) else "ตกจากฝั่ง / ท่าเรือ") if not location.is_empty() else "ประวัติก่อนเพิ่มแผนที่ · ไม่มีพิกัด"]
  %Note.text = profile.data.map_memory.notes.get(record.get("catch_id", ""), "")
 elif kind == "spot":
  %DetailTitle.text = selected.spot.name
  %Detail.text = "จุดโปรดของคุณ\n" + ("บันทึกจากเรือ" if selected.spot.from_boat else "จุดยืนตกปลา")
  %Favorite.text = "ลบจุดโปรด"
 elif kind == "point":
  %DetailTitle.text = "จุดที่เลือก"
  %Detail.text = "บันทึกเป็นจุดโปรดได้ทันที\nเกมจะตั้งชื่อให้อัตโนมัติ"
 elif kind == "boss" and not boss_info.is_empty():
  %DetailTitle.text = "จ้าวบ่อ · %s" % boss_info.display_name
  %Detail.text = "น้ำหนัก %.2f กก.\nพิชิตแล้ว %d ครั้ง\n%s\nปลาเคลื่อนที่ได้ตามธรรมชาติ" % [boss_info.weight, boss_info.victories, "ตำแหน่งขณะเปิดแผนที่" if boss_info.live else "ตำแหน่งจากข้อมูลที่บันทึกไว้"]
 var point: Variant = _selected_point()
 if not _matching_spot().is_empty():
  %Favorite.text = "ลบจุดโปรด"
 %Favorite.disabled = point == null or profile.incompatible
 %Navigate.disabled = point == null or map_id != session_map
 if point != null and map_id != session_map:
  %Detail.text += "\nเข้าแหล่งน้ำนี้ก่อนเริ่มนำทาง"

func _selected_point() -> Variant:
 match selected.get("kind", ""):
  "catch":
   if FishingJournal.valid_location(selected.record.get("location")):
    return selected.record.location.angler_xz
  "spot": return selected.spot.position
  "point": return selected.point
 return null

func _navigate() -> void:
 var point: Variant = _selected_point()
 if point == null or map_id != session_map:
  return
 target = {"position": point, "map": map_id}
 target_changed.emit(target)
 close()

func _favorite() -> void:
 var success := false
 var existing := _matching_spot()
 if not existing.is_empty():
  success = profile.remove_fishing_spot(existing.id)
  if success and selected.get("kind") == "spot":
   selected = {}
 else:
  var point: Variant = _selected_point()
  if point != null:
   var boat: bool = selected.get("kind") == "catch" and selected.record.location.from_boat
   success = profile.add_fishing_spot(map_id, point, boat)
 %Notice.text = ("ลบจุดโปรดแล้ว" if not existing.is_empty() else "บันทึกจุดโปรดแล้ว") if success else _save_error()
 _refresh()
 _emit_spots()

func _matching_spot() -> Dictionary:
 if selected.get("kind") == "spot":
  return selected.spot
 var point: Variant = _selected_point()
 if point != null:
  for spot in _spots(map_id):
   if spot.position.distance_squared_to(point) <= 1.0:
    return spot
 return {}

func _save_here() -> void:
 if not is_instance_valid(player) or map_id != session_map:
  return
 var point := Vector2(player.global_position.x, player.global_position.z)
 var success := profile.add_fishing_spot(map_id, point, player.boat != null)
 %Notice.text = "บันทึกจุดที่ยืนอยู่แล้ว" if success else _save_error()
 _refresh()
 _emit_spots()

func _save_note() -> void:
 if selected.get("kind") != "catch":
  return
 var success := profile.set_catch_note(selected.record.get("catch_id", ""), %Note.text)
 %Notice.text = "บันทึกโน้ตแล้ว" if success else _save_error()

func _save_error() -> String:
 return profile.save_error if not profile.save_error.is_empty() else "บันทึกไม่ได้ · จุดโปรดเก็บได้สูงสุด 200 จุด"
