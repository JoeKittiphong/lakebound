class_name ShopShelfBrowser
extends Control
signal item_pressed(item: TackleItem)
signal page_changed
@export var page_size := 12
@export var maximum_page_size := 12
@export var camera_height := 3.66
@export var rod_spacing := .60
@export var object_spacing := 1.20
@export var rod_display_height := 3.15
@export var object_display_height := .92
@export var object_display_width := .73
@export var box_display_width := .86
@export var transition_seconds := .16
@export var swipe_threshold := .10
var profile:AnglerProfile
var selected_id:=""
var items: Array[TackleItem] = []
var page := 0
var rod_zone := true
var _pressed := false
var _touch_id := -1
var _start := Vector2.ZERO
var _travel := 0.0
var _drag_x := 0.0
var _tween: Tween
var _generation := 0
@onready var viewport: SubViewport = $View/Viewport
@onready var display: Node3D = $View/Viewport/Room/Display
@onready var camera: Camera3D = $View/Viewport/Room/Camera

func _ready() -> void:
 resized.connect(_resize)
 visibility_changed.connect(func():
  if not is_visible_in_tree(): release_models()
  elif not items.is_empty(): _load_page())

func page_count() -> int: return maxi(1, ceili(float(items.size()) / page_size))
func slots() -> Array[Node]: return display.get_node("RodSlots" if rod_zone else "DisplaySlots").get_children()

func set_items(values: Array[TackleItem], rods: bool, keep_page := false) -> void:
 if _tween != null: _tween.kill()
 items = values; rod_zone = rods
 page = clampi(page if keep_page else 0, 0, page_count() - 1)
 _load_page()

func release_models() -> void:
 _generation += 1
 _pressed = false; _touch_id = -1
 if _tween != null: _tween.kill()
 if not is_node_ready(): return
 for parent in [display.get_node("RodSlots"), display.get_node("DisplaySlots")]:
  for slot: ShopShelfSlot in parent.get_children(): slot.clear()
 display.position.x = 0
 viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
 $View.stretch = false
 viewport.size = Vector2i(2,2)

func _load_page() -> void:
 release_models()
 if not is_visible_in_tree(): return
 page_size = _capacity()
 page = clampi(page,0,page_count()-1)
 display.get_node("RodRack").visible = rod_zone
 display.get_node("DisplayShelf").visible = not rod_zone
 display.get_node("RodSlots").visible = rod_zone
 display.get_node("DisplaySlots").visible = not rod_zone
 var active := slots()
 var visible_count:=mini(page_size,maxi(0,items.size()-page*page_size))
 for i in active.size():
  var index := page * page_size + i
  var columns := maxi(1,visible_count) if rod_zone else maxi(1,mini(floori(page_size/2.0),ceili(visible_count/2.0)))
  var row_columns:=columns if rod_zone else mini(columns,maxi(1,visible_count-floori(float(i)/columns)*columns))
  active[i].position.x = (float(i % columns) - float(row_columns - 1) * .5) * (rod_spacing if rod_zone else object_spacing)
  if not rod_zone: active[i].position.y = 2.01 if i < columns else .51
  if i < page_size and index < items.size():
   active[i].mount(items[index])
 var boxes_only:=not items.is_empty() and items.all(func(entry:TackleItem):return entry.kind=="box")
 var box_scale:=INF
 if boxes_only:
  for slot:ShopShelfSlot in active:
   if slot.item==null:continue
   var bounds:=slot.local_bounds()
   box_scale=minf(box_scale,minf(object_display_height/maxf(bounds.size.y,.001),box_display_width/maxf(maxf(bounds.size.x,bounds.size.z),.001)))
 for slot: ShopShelfSlot in active:
  if slot.item == null: continue
  var box := slot.local_bounds()
  # Uniformly scale each display model so a long pole does not shrink every
  # other product. Real dimensions remain visible in the item detail panel.
  var scale_value := rod_display_height / maxf(box.size.y,.001) if rod_zone else minf(object_display_height / maxf(box.size.y,.001), object_display_width / maxf(maxf(box.size.x,box.size.z),.001))
  if boxes_only:scale_value=box_scale
  slot.place(scale_value)
 _resize(false)
 refresh_badges()
 page_changed.emit()

func _capacity() -> int:
 var width := camera_height * size.x / maxf(1,size.y)
 if rod_zone:
  var count := clampi(floori((width - .45) / rod_spacing) + 1,2,maximum_page_size)
  return maxi(2,count - count % 2)
 return clampi(floori((width - .90) / object_spacing) + 1,2,floori(maximum_page_size / 2.0)) * 2

func _resize(reload_capacity := true) -> void:
 if not is_node_ready() or not is_visible_in_tree(): return
 if reload_capacity and page_size != _capacity():
  var first := page * page_size
  page_size = _capacity()
  page = mini(floori(float(first) / page_size),page_count()-1)
  _load_page()
  return
 $View.stretch = false
 viewport.size = Vector2i(maxi(1,roundi(size.x)),maxi(1,roundi(size.y)))
 $View.stretch = true
 camera.size = camera_height
 _redraw()

func _redraw() -> void:
 if is_visible_in_tree(): viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _offset(value: float) -> void:
 display.position.x = value
 _redraw()

func change_page(step: int, animated := true) -> void:
 var next := clampi(page + step,0,page_count()-1)
 if _tween != null: _tween.kill()
 _pressed = false; _touch_id = -1
 if next == page:
  _tween = create_tween();_tween.tween_method(_offset,display.position.x,0.0,transition_seconds)
  return
 if not animated:
  page = next;_load_page();return
 _generation += 1
 var generation := _generation
 _tween = create_tween()
 _tween.tween_method(_offset,display.position.x,-signf(step)*8.2,transition_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 _tween.tween_callback(func():
  if generation != _generation: return
  page = next
  _load_page()
  _offset(signf(step)*8.2)
  _tween = create_tween()
  _tween.tween_method(_offset,display.position.x,0.0,transition_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))

func pick(pointer_position: Vector2) -> TackleItem:
 var local := pointer_position * Vector2(viewport.size) / size
 var origin := camera.project_ray_origin(local)
 var direction := camera.project_ray_normal(local)
 var nearest := INF
 var selected: TackleItem
 for slot: ShopShelfSlot in slots():
  var distance := slot.hit_distance(origin,direction)
  if distance < nearest: nearest = distance;selected = slot.item
 return selected

func _begin(pointer_position: Vector2) -> void:
 if _tween != null and _tween.is_running(): return
 _pressed = true;_start = pointer_position;_travel = 0;_drag_x = 0
func _drag(pointer_position: Vector2) -> void:
 if not _pressed: return
 _drag_x = pointer_position.x - _start.x
 _travel = maxf(_travel,pointer_position.distance_to(_start))
 if _travel > 12: _offset(clampf(_drag_x / maxf(1,size.x),-.8,.8)*3.4)
func _end(pointer_position: Vector2) -> void:
 if not _pressed: return
 _pressed = false
 if _travel < 12:
  var selected := pick(pointer_position)
  if selected != null: item_pressed.emit(selected)
 elif absf(_drag_x) > size.x*swipe_threshold:
  change_page(1 if _drag_x < 0 else -1)
 else: change_page(0)

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton:
  if event.button_index == MOUSE_BUTTON_LEFT:
   if event.pressed: _begin(event.position)
   else: _end(event.position)
   accept_event()
  elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT]:
   change_page(1 if event.button_index == MOUSE_BUTTON_WHEEL_RIGHT else -1);accept_event()
 elif event is InputEventMouseMotion and _pressed: _drag(event.position);accept_event()
 elif event is InputEventScreenTouch:
  if event.pressed and _touch_id == -1: _touch_id = event.index;_begin(event.position)
  elif not event.pressed and event.index == _touch_id: _end(event.position);_touch_id = -1
  accept_event()
 elif event is InputEventScreenDrag and event.index == _touch_id: _drag(event.position);accept_event()

func refresh_badges()->void:
 if not is_node_ready():return
 for slot:ShopShelfSlot in slots():
  var badge:=slot.get_node_or_null("FitBadge") as Label3D
  if badge==null:continue
  if slot.item==null:badge.text="";continue
  var blocked:=profile!=null and not EquipmentChoiceRules.error(profile,slot.item).is_empty()
  badge.text=("● " if str(slot.item.id)==selected_id else "")+("×" if blocked else "✓")
  badge.modulate=Color(.55,.59,.61) if blocked else Color(.5,1,.7)
 _redraw()
