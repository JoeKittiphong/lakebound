class_name EquipmentModelPreview
extends Control
signal inspect_requested(item: Resource)
@export var interactive: bool = false
@export var show_full_rod: bool = false
@export_range(0.05,0.5) var visibility_check_seconds: float = 0.12
@export_range(1.0,1.5) var frame_padding: float = 1.15
var item: Resource
var instance: Node3D
var _source: PackedScene
var _elapsed := 0.0
var _generation := 0
var _pressed := false
var _pan_mode := false
var _travel := 0.0
var _zoom := 1.0
var _fit_size := 1.0
var _touches: Dictionary = {}
@onready var viewport: SubViewport = $View/Viewport
@onready var pivot: Node3D = $View/Viewport/Studio/Pivot
@onready var camera: Camera3D = $View/Viewport/Studio/Camera
func _ready()->void:
 $Hint.visible=not interactive
 visibility_changed.connect(_on_visibility_changed)
 resized.connect(_refit_after_resize)
func set_item(value: Resource)->void:
 item=value
 if is_node_ready():$Hint.text="แตะดูทั้งคัน" if value!=null and value.kind=="rod" else "แตะดูใกล้"
 var scene: PackedScene=value.model_scene if value!=null else null
 if scene!=_source:
  release_model()
  _source=scene
 _elapsed=visibility_check_seconds
func _on_visibility_changed()->void:
 if not is_visible_in_tree():release_model()
func on_screen()->bool:
 if not is_visible_in_tree() or size.x<1 or size.y<1:return false
 var rect:=get_global_rect()
 if not get_viewport_rect().intersects(rect):return false
 var ancestor:=get_parent()
 while ancestor!=null:
  if ancestor is ScrollContainer and not ancestor.get_global_rect().intersects(rect):return false
  ancestor=ancestor.get_parent()
 return true
func _process(delta:float)->void:
 _elapsed+=delta
 if _elapsed<visibility_check_seconds:return
 _elapsed=0
 if on_screen() and _source!=null:
  if not is_instance_valid(instance):_load_model()
 elif is_instance_valid(instance):release_model()
func _load_model()->void:
 _generation+=1
 var generation:=_generation
 viewport.size=Vector2i(maxi(1,int(size.x)),maxi(1,int(size.y)))
 $View.stretch=true
 _zoom=1.0;pivot.rotation=Vector3.ZERO;pivot.position=Vector3.ZERO
 instance=_source.instantiate() as Node3D
 pivot.add_child(instance)
 if item.kind=="rod":
  instance.rotation.z=-PI*.5
  instance.set_load(0,0)
  if is_instance_valid(instance.held_reel):
   instance.held_reel.get_parent().remove_child(instance.held_reel)
   instance.held_reel.queue_free();instance.held_reel=null
  if instance is DetailedFishingRod:
   instance.get_node("GuideLine").hide()
   instance.get_node("FeedLine").hide()
 else:instance.rotation_degrees=Vector3(-12,-20,-12)
 _freeze(instance)
 await get_tree().process_frame
 if generation!=_generation or not is_instance_valid(instance):return
 fit_camera()
 viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
func _freeze(node:Node)->void:
 node.set_process(false);node.set_physics_process(false)
 for child in node.get_children():_freeze(child)
func points(node:Node)->PackedVector3Array:
 var result:=PackedVector3Array()
 if node is MeshInstance3D and node.visible and node.mesh!=null:
  var box: AABB=node.get_aabb()
  for i in 8:result.append(node.global_transform*box.get_endpoint(i))
 for child in node.get_children():result.append_array(points(child))
 return result
func fit_camera()->void:
 if not is_instance_valid(instance):return
 var corners:=framing_points()
 if corners.is_empty():return
 var bounds:=AABB(corners[0],Vector3.ZERO)
 for corner in corners:bounds=bounds.expand(corner)
 instance.position-=pivot.to_local(bounds.get_center())
 # Fixed three-quarter views make the reel foot, spool and handle readable.
 var camera_side:float=-4.0 if item.kind=="rod" and item.mount_layout in ["spinning","fly","ice","fixed"] else 4.0
 camera.position=Vector3(1.5,1.3,camera_side).normalized()*maxf(bounds.size.length()*2.0,.25)
 camera.look_at(Vector3.ZERO)
 corners=framing_points()
 var projected:=AABB(camera.to_local(corners[0]),Vector3.ZERO)
 for corner in corners:projected=projected.expand(camera.to_local(corner))
 var aspect:=float(viewport.size.x)/maxf(1.0,float(viewport.size.y))
 _fit_size=maxf(projected.size.y,projected.size.x/aspect)*frame_padding
 camera.size=maxf(_fit_size,.015)
 # Fit against the actual viewport projection as well (including keep-aspect mode).
 var first:=camera.unproject_position(corners[0])
 var screen:=Rect2(first,Vector2.ZERO)
 for corner in corners:screen=screen.expand(camera.unproject_position(corner))
 var coverage:=maxf(screen.size.x/maxf(1.0,viewport.size.x),screen.size.y/maxf(1.0,viewport.size.y))
 _fit_size=camera.size*coverage*frame_padding
 camera.size=maxf(_fit_size*_zoom,.015)
 _request_frame()
func framing_points()->PackedVector3Array:
 if item.kind=="rod" and not show_full_rod and instance is DetailedFishingRod:
  # Useful card scale: grip, reel seat and first guides; inspection offers full length.
  var grip:float=instance.config.grip_x
  var end:float=minf(instance.config.length-grip,maxf(.62,instance.config.h*.75))
  var box:=AABB(Vector3(-.12,-grip,-.15),Vector3(.24,end+grip,.30))
  var corners:=PackedVector3Array()
  for i in 8:corners.append(instance.global_transform*box.get_endpoint(i))
  return corners
 return points(instance)
func release_model()->void:
 _generation+=1
 _pressed=false
 _touches.clear()
 if is_instance_valid(instance):
  pivot.remove_child(instance);instance.queue_free()
 instance=null
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 $View.stretch=false
 viewport.size=Vector2i(2,2)
func _request_frame()->void:
 if is_node_ready() and is_instance_valid(instance):viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
func _refit_after_resize()->void:
 if not is_node_ready():return
 await get_tree().process_frame
 if is_instance_valid(instance):
  $View.stretch=false
  viewport.size=Vector2i(maxi(1,int(size.x)),maxi(1,int(size.y)))
  $View.stretch=true
  fit_camera()
func reset_view()->void:
 pivot.position=Vector3.ZERO;pivot.rotation=Vector3.ZERO;_zoom=1.0
 fit_camera()
func pan_view(relative:Vector2)->void:
 var factor:=camera.size/maxf(1.0,minf(viewport.size.x,viewport.size.y))
 pivot.position+=(camera.basis.x*relative.x-camera.basis.y*relative.y)*factor
 _request_frame()
func _set_zoom(factor:float)->void:
 _zoom=clampf(_zoom*factor,.12,2.0)
 camera.size=maxf(.015,_fit_size*_zoom);_request_frame()
func _gui_input(event:InputEvent)->void:
 if event is InputEventMouseButton:
  if interactive and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   _set_zoom(.85 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.18);accept_event();return
  if event.button_index==MOUSE_BUTTON_LEFT or (interactive and event.button_index==MOUSE_BUTTON_RIGHT):
   if event.pressed:_pressed=true;_travel=0;_pan_mode=interactive and (event.button_index==MOUSE_BUTTON_RIGHT or event.shift_pressed)
   elif _pressed:
    _pressed=false
    if not interactive and _travel<12 and item!=null:inspect_requested.emit(item)
 elif event is InputEventMouseMotion and _pressed:
  _travel+=event.relative.length()
  if interactive:
   if _pan_mode:pan_view(event.relative)
   else:pivot.rotate_y(event.relative.x*.012);pivot.rotate_x(event.relative.y*.008);_request_frame()
   accept_event()
 elif event is InputEventScreenTouch:
  if event.pressed:_touches[event.index]=event.position;_travel=0
  else:
   _touches.erase(event.index)
   if not interactive and _travel<12 and item!=null:inspect_requested.emit(item)
 elif event is InputEventScreenDrag:
  _travel+=event.relative.length()
  if interactive:
   if _touches.size()==2 and _touches.has(event.index):
    var keys:=_touches.keys();var before:float=_touches[keys[0]].distance_to(_touches[keys[1]])
    _touches[event.index]=event.position
    var after:float=_touches[keys[0]].distance_to(_touches[keys[1]])
    if before>1 and after>1:_set_zoom(before/after)
    pan_view(event.relative*.5)
   else:
    _touches[event.index]=event.position
    pivot.rotate_y(event.relative.x*.012);pivot.rotate_x(event.relative.y*.008);_request_frame()
   accept_event()
 elif interactive and event is InputEventMagnifyGesture:
  _set_zoom(1.0/event.factor);accept_event()
