class_name MapCarousel
extends Control

signal region_selected(id: String)
@export_enum("Cards with side previews", "Wide image") var layout_style := 0
@export var swipe_threshold := 55.0
const ART = {
 "river":preload("res://assets/ui/maps/rainforest_lake.png"),
 "lotus_marsh":preload("res://assets/ui/maps/lotus_marsh.png"),
 "forest_stream":preload("res://assets/ui/maps/forest_stream.png"),
 "wild_reservoir":preload("res://assets/ui/maps/wild_reservoir.png"),
 "mangrove_estuary":preload("res://assets/ui/maps/mangrove_estuary.png"),
 "coral_coast":preload("res://assets/ui/maps/coral_coast.png")}
var index := 0
var _finger := -1
var _start := Vector2.ZERO
var _fade: Tween

func _ready() -> void:
 %Previous.pressed.connect(func(): step(-1))
 %Next.pressed.connect(func(): step(1))
 %Images.gui_input.connect(_on_image_input)
 resized.connect(_responsive)
 set_style(layout_style)
 _refresh()

func set_style(style: int) -> void:
 layout_style = clampi(style,0,1)
 if is_node_ready():
  _responsive()

func _responsive() -> void:
 var peeks := layout_style == 0 and size.x >= 650
 %LeftPreview.visible = peeks
 %RightPreview.visible = peeks

func set_region(id: String, emit_selection: bool = false) -> void:
 for i in RegionCatalog.MAPS.size():
  if RegionCatalog.MAPS[i].id == id:
   index = i
   break
 if is_node_ready():
  _refresh()
 if emit_selection:
  region_selected.emit(RegionCatalog.MAPS[index].id)

func step(direction: int) -> void:
 index = posmod(index+direction,RegionCatalog.MAPS.size())
 _refresh()
 if is_instance_valid(_fade): _fade.kill()
 %Picture.modulate.a = 0.55
 _fade = create_tween()
 _fade.tween_property(%Picture,"modulate:a",1.0,0.18)
 region_selected.emit(RegionCatalog.MAPS[index].id)

func _refresh() -> void:
 var entry: Dictionary = RegionCatalog.MAPS[index]
 %Picture.texture = ART[entry.id]
 %LeftPreview.texture = ART[RegionCatalog.MAPS[posmod(index-1,6)].id]
 %RightPreview.texture = ART[RegionCatalog.MAPS[(index+1)%6].id]
 %Name.text = entry.name
 %Count.text = "%02d / %02d   ·   %s" % [index+1,RegionCatalog.MAPS.size(),"○".repeat(index)+"●"+"○".repeat(RegionCatalog.MAPS.size()-index-1)]

func _on_image_input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed and _finger == -1:
   _finger = event.index
   _start = event.position
  elif not event.pressed and event.index == _finger:
   _finger = -1
   if not event.canceled:
    _finish_swipe(event.position)
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
  if event.pressed:
   _finger = -2
   _start = event.position
  elif _finger == -2:
   _finger = -1
   _finish_swipe(event.position)
 %Images.accept_event()

func _finish_swipe(point: Vector2) -> void:
 var delta := point-_start
 if absf(delta.x) >= swipe_threshold and absf(delta.x)>absf(delta.y)*1.2:
  step(1 if delta.x<0 else -1)
 elif delta.length() < 12 and %LeftPreview.visible:
  if point.x < %LeftPreview.size.x:
   step(-1)
  elif point.x > %Images.size.x-%RightPreview.size.x:
   step(1)

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  _finger = -1
