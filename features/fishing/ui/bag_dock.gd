extends Control
signal category_requested(index: int)
signal fish_requested
signal boat_requested
@export var swipe_distance := 36.0
var profile: AnglerProfile
var fishing: FishingController
var page := 0
var session_fish := false
var records: Array = []
var _finger := -2
var _start := Vector2.ZERO
const KEYS := ["rod", "reel", "line", "bait"]
const CATEGORIES := [2, 3, 4, 1]
func _ready() -> void:
 for i in 4:
  $Equipment.get_child(i).pressed.connect(func():
   if _can_change():category_requested.emit(CATEGORIES[i]))
 $Fish.gui_input.connect(_fish_input)
 $Equipment/Boat.pressed.connect(func():boat_requested.emit())
func bind(value: AnglerProfile, controller: FishingController) -> void:
 profile=value
 fishing=controller
 profile.changed.connect(refresh)
 fishing.state_changed.connect(refresh)
 refresh()
func _can_change() -> bool:
 return fishing!=null and fishing.state in [FishingController.State.READY,FishingController.State.LOST]
func clear_fish() -> void:
 records.clear()
 page=0
 refresh()
func add_fish(record: Dictionary) -> void:
 records.append(record)
 page=maxi(0,ceili(records.size()/4.0)-1)
 refresh()
func refresh() -> void:
 if profile==null:return
 for i in 4:
  var button: Button=$Equipment.get_child(i)
  var item:=profile.equipped(KEYS[i])
  button.icon=null
  button.get_node("Preview").set_resource(item)
  button.tooltip_text=profile.equipment_name(KEYS[i])
  button.disabled=not _can_change()
  if i==3:button.get_node("Caption").text="เหยื่อ %d"%profile.quantity(str(item.id)) if item!=null else "เหยื่อ"
 if not session_fish:records=profile.data.catches.duplicate()
 var boat_item := profile.equipped("boat")
 $Equipment/Boat.get_node("Preview").set_resource(boat_item)
 $Equipment/Boat.tooltip_text = "ใช้เรือที่เลือก · ต้องยืนบนฝั่ง" if boat_item != null else "เรือ · ซื้อและเลือกใช้จากร้านก่อน"
 page=clampi(page,0,maxi(0,ceili(records.size()/4.0)-1))
 $PageHint.text="ปลา %d/%d · ปัดซ้าย–ขวา"%[page+1,maxi(1,ceili(records.size()/4.0))]
 for i in 4:
  var button: Button=$Fish.get_child(i)
  var index:=page*4+i
  button.icon=null
  var species: FishSpecies
  button.get_node("Caption").text="ว่าง"
  button.tooltip_text="ปัดซ้ายขวาเพื่อดูปลาเพิ่มเติม"
  if index<records.size():
   var record: Dictionary=records[index]
   species=FishCatalog.find(StringName(record.species))
   button.get_node("Caption").text="%.2f กก."%float(record.weight)
   button.tooltip_text="%s · %.2f กก. · %d/%d"%[record.get("name","ปลา"),record.weight,index+1,records.size()]
  button.get_node("Preview").set_resource(species)
func change_page(step: int) -> void:
 page=clampi(page+step,0,maxi(0,ceili(records.size()/4.0)-1))
 refresh()
func _fish_input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed and _finger==-2:
   _finger=event.index
   _start=event.position
  elif not event.pressed and event.index==_finger:
   _finish(event.position)
 elif event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:
    _finger=-1
    _start=event.position
   elif _finger==-1:_finish(event.position)
  elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   change_page(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1)
 accept_event()
func _finish(position: Vector2) -> void:
 var distance:=position.x-_start.x
 _finger=-2
 if absf(distance)>=swipe_distance:change_page(1 if distance<0 else -1)
 elif not session_fish and _can_change():fish_requested.emit()
