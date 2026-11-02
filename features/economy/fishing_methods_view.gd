extends VBoxContainer

const Row = preload("res://features/economy/method_fish_row.tscn")
var profile: AnglerProfile
var map_index := 0
var groups: Array = []
var selected_species := ""
var records: Array = []
var _row_group := ButtonGroup.new()

func _ready() -> void:
 for region in RegionCatalog.MAPS:
  %Maps.add_tab(region.name)
 %Maps.tab_changed.connect(_map_changed)
 %Capture.item_selected.connect(_show_capture)
 visibility_changed.connect(refresh)

func bind(value: AnglerProfile) -> void:
 if is_instance_valid(profile) and profile.changed.is_connected(refresh):
  profile.changed.disconnect(refresh)
 profile = value
 profile.changed.connect(refresh)
 refresh()

func _exit_tree() -> void:
 if is_instance_valid(profile) and profile.changed.is_connected(refresh):
  profile.changed.disconnect(refresh)

func _map_changed(index: int) -> void:
 map_index = index
 selected_species = ""
 refresh()

func refresh() -> void:
 if profile == null or not is_node_ready() or not is_visible_in_tree(): return
 groups = FishingMethods.grouped(profile.data.journal,RegionCatalog.MAPS[map_index].id)
 for child in %FishRows.get_children(): child.free()
 %ListHint.text = "%s · %d ชนิด" % [RegionCatalog.MAPS[map_index].name,groups.size()]
 %Empty.visible = groups.is_empty()
 %Detail.visible = false
 %Empty.text = "ยังไม่เคยจับปลาในแผนที่นี้\nบันทึกจะเพิ่มเมื่อจับปลาสำเร็จ" if groups.is_empty() else "แตะภาพปลาทางซ้าย\nเพื่อดูอุปกรณ์และวิธีตก"
 if groups.is_empty():
  records = []
  return
 var chosen := -1
 for i in groups.size():
  var group: Dictionary = groups[i]
  var row := Row.instantiate()
  %FishRows.add_child(row)
  row.button_group = _row_group
  row.get_node("Row/Text/Name").text = group.name
  var species := FishCatalog.find(StringName(group.species))
  row.get_node("Row/Icon").texture = species.collection_icon if species != null else null
  row.pressed.connect(_select_species.bind(i))
  if group.species == selected_species: chosen = i
 if chosen >= 0:
  _select_species(chosen)
 else:
  records = []
  %Empty.show()

func _select_species(index: int) -> void:
 %Empty.hide()
 %Detail.show()
 var group: Dictionary = groups[index]
 selected_species = group.species
 records = group.records
 for i in %FishRows.get_child_count():
  var row := %FishRows.get_child(i)
  row.set_pressed_no_signal(i==index)
  for label: Label in row.get_node("Row/Text").get_children():
   label.add_theme_color_override("font_color",Color(0.04,0.16,0.19) if i==index else Color.WHITE)
 %FishName.text = group.name
 %Capture.clear()
 for i in records.size():
  %Capture.add_item("%s · %.2f กก." % ["ล่าสุด" if i==0 else "ครั้งก่อน #%d"%i,float(records[i].weight)])
 _show_capture(0)

func _show_capture(index: int) -> void:
 if index < 0 or index >= records.size(): return
 var record: Dictionary = records[index]
 %CatchInfo.text = "%.2f กก." % float(record.weight)
 %Bait.text = FishingMethods.gear_name(record,"bait")
 %Line.text = FishingMethods.gear_name(record,"line")
 %Rod.text = FishingMethods.gear_name(record,"rod")
 %Reel.text = FishingMethods.gear_name(record,"reel")
 %Depth.text = "%.1f ม." % float(record.depth) if record.has("depth") else "ไม่ได้บันทึก"
 %Brake.text = FishingMethods.setting(record,"drag_strength","%")
 %Distance.text = FishingMethods.setting(record,"cast_distance","ม.")
