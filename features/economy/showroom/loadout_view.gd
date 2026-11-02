class_name EquipmentLoadoutView
extends Control
signal item_pressed(item:TackleItem)
@export var minimum_camera_height:=2.65
@export var minimum_camera_width:=4.35
@export var rod_display_width:=3.6
@export var component_height:=.67
@export var component_width:=.70
var profile:AnglerProfile
var _ids:PackedStringArray=[]
var _down:=Vector2.ZERO
var _pressed:=false
var _travel:=0.0
@onready var viewport:SubViewport=$View/Viewport
@onready var camera:Camera3D=$View/Viewport/Studio/Camera
@onready var slots:Node3D=$View/Viewport/Studio/Slots
func _ready()->void:
 resized.connect(_resize)
 visibility_changed.connect(func():
  if is_visible_in_tree() and profile!=null:refresh()
  else:release_models())
func set_profile(value:AnglerProfile)->void:
 profile=value
 if is_visible_in_tree():refresh()
func refresh()->void:
 if profile==null or not is_visible_in_tree():return
 var ids:PackedStringArray=[]
 for key in ["rod","reel","line","bait","box"]:ids.append(str(profile.data.equipped.get(key,"")))
 ids.append(str(profile.data.line_remaining))
 if ids==_ids:return
 release_models();_ids=ids
 $EmptyMessage.visible = profile.equipped("rod") == null
 # Keep the gameplay rod, reel-foot alignment and guide routing together.
 var rod_slot:ShopShelfSlot=slots.get_node("Rod")
 rod_slot.mount(profile.equipped("rod"))
 var rod:=rod_slot.model as DetailedFishingRod
 if rod!=null:
  rod._held_scene=null
  if rod.accepts_reel:rod.set_held_reel(profile.equipped("reel").model_scene if profile.equipped("reel") != null else null)
  rod.set_line_attached(profile.equipped("line") != null)
  if profile.equipped("line") != null: rod.set_line_style(profile.equipped("line").line_visual_style)
  rod.rotation=Vector3(.20,rod.rotation.y+.30,-PI*.5)
  rod_slot.place(rod_display_width/maxf(rod_slot.local_bounds().size.x,.001))
  rod_slot.position=Vector3(0,.15,0)
  rod.set_load(0,0)
  var bait_slot:ShopShelfSlot=slots.get_node("Bait")
  bait_slot.mount(profile.equipped("bait"))
  var bounds:=bait_slot.local_bounds()
  bait_slot.place(.14/maxf(bounds.size.length(),.001))
  # Hang the selected bait below the tip, with the leader ending at its upper eye.
  bait_slot.position=rod.tip.global_position+Vector3(-.10,-.65,0)
  var bait_bounds:=bait_slot.local_bounds()
  $View/Viewport/Studio/LeaderEnd.global_position=bait_slot.global_position+Vector3(0,bait_bounds.end.y,0)
  var leader=$View/Viewport/Studio/Leader
  leader.material_override=rod.ribbon.material_override.duplicate()
  leader.start_anchor=leader.get_path_to(rod.tip)
  leader.camera_path=leader.get_path_to(camera)
  leader.visible = profile.equipped("line") != null and profile.equipped("bait") != null
  rod.update_guides()
  if leader.visible: leader.refresh()
  if is_instance_valid(rod.held_reel):
   var capacity:=profile.line_capacity()
   rod.held_reel.advance(0,0,0,clampf(profile.data.line_remaining/maxf(capacity,1),.05,1))
 var box_slot:ShopShelfSlot=slots.get_node("Box")
 box_slot.mount(profile.equipped("box"))
 var box:=box_slot.local_bounds()
 box_slot.place(minf(component_height/maxf(box.size.y,.001),component_width/maxf(maxf(box.size.x,box.size.z),.001)))
 box_slot.position=Vector3(-1.45,-1.02,0)

 _resize()
func release_models()->void:
 _ids=[]
 if not is_node_ready():return
 for slot:ShopShelfSlot in slots.get_children():slot.clear()
 $View/Viewport/Studio/Leader.hide()
 $View.stretch=false;viewport.size=Vector2i(2,2)
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
func _resize()->void:
 if not is_node_ready() or not is_visible_in_tree():return
 $View.stretch=false
 viewport.size=Vector2i(maxi(1,roundi(size.x)),maxi(1,roundi(size.y)))
 $View.stretch=true
 camera.size=maxf(minimum_camera_height,minimum_camera_width*size.y/maxf(1,size.x))
 if is_instance_valid(assembled_rod()):assembled_rod().update_guides()
 if $View/Viewport/Studio/Leader.visible:$View/Viewport/Studio/Leader.refresh()
 viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
func assembled_rod()->DetailedFishingRod:
 return slots.get_node("Rod").model as DetailedFishingRod
func _mesh_hit(node:Node3D,origin:Vector3,direction:Vector3)->float:
 var distance:=INF
 if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh!=null:
  var inverse:=node.global_transform.affine_inverse()
  var point:Variant=node.get_aabb().grow(.012).intersects_ray(inverse*origin,inverse.basis*direction)
  if point is Vector3:distance=origin.distance_to(node.global_transform*point)
 for child in node.get_children():
  if child is Node3D:distance=minf(distance,_mesh_hit(child,origin,direction))
 return distance
func pick(pointer_position:Vector2)->TackleItem:
 var pixel:=pointer_position*Vector2(viewport.size)/size
 var origin:=camera.project_ray_origin(pixel);var direction:=camera.project_ray_normal(pixel)
 var rod:=assembled_rod()
 if rod==null:
  var box_slot:ShopShelfSlot=slots.get_node("Box")
  return box_slot.item if is_instance_valid(box_slot.model) and _mesh_hit(box_slot.model,origin,direction)<INF else null
 # Small components take priority over the shaft behind them.
 if is_instance_valid(rod.held_reel) and _mesh_hit(rod.held_reel,origin,direction)<INF:return profile.equipped("reel")
 for key in ["Bait","Box"]:
  var slot:ShopShelfSlot=slots.get_node(key)
  if is_instance_valid(slot.model) and _mesh_hit(slot.model,origin,direction)<INF:return slot.item
 var points:=PackedVector3Array([rod.tip.global_position,$View/Viewport/Studio/LeaderEnd.global_position])
 for i in range(points.size()-1):
  var from:=camera.unproject_position(points[i]);var to:=camera.unproject_position(points[i+1])
  if $View/Viewport/Studio/Leader.visible and pixel.distance_to(Geometry2D.get_closest_point_to_segment(pixel,from,to))<14:return profile.equipped("line")
 if _mesh_hit(rod,origin,direction)<INF:return profile.equipped("rod")
 return null
func select_component(key:String)->void:
 if profile==null:return
 if key=="reel" and (profile.equipped("rod") == null or profile.equipped("rod").mount_layout=="fixed"):return
 item_pressed.emit(profile.equipped(key))
func _gui_input(event:InputEvent)->void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:_down=event.position;_pressed=true;_travel=0
  elif _pressed:
   _pressed=false
   if _travel<12:
    var item:=pick(event.position)
    if item!=null:item_pressed.emit(item)
  accept_event()
 elif event is InputEventMouseMotion and _pressed:_travel=maxf(_travel,event.position.distance_to(_down))
 elif event is InputEventScreenTouch:
  if event.pressed:_down=event.position;_pressed=true;_travel=0
  elif _pressed:
   _pressed=false
   if _travel<12:
    var item:=pick(event.position)
    if item!=null:item_pressed.emit(item)
  accept_event()
 elif event is InputEventScreenDrag and _pressed:_travel=maxf(_travel,event.position.distance_to(_down))
