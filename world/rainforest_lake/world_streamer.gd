class_name LakeWorldStreamer
extends Node3D
## Loads only authored detail-cell scenes. Terrain and low-detail forest remain visible in the editor.
@export var player: Node3D
@export_dir var cells_directory := "res://world/rainforest_lake/cells"
@export var cell_size := 50.0
@export var load_radius := 125.0
@export var unload_radius := 195.0
@export var maximum_cells := 44
@export var maximum_inflight := 1
@export var instantiate_budget_ms := 2.0
@export var mobile_target_fps := 30
@export var available_cells: Array[Vector2i] = []
var loaded: Dictionary = {}
var pending: Dictionary = {}
var wanted: Array[Vector2i] = []
var clock := 0.0
var peak_cells := 0
var peak_instantiation_ms := 0.0
var requests_failed := 0

func _ready() -> void:
 if player==null:player=get_node_or_null("../../Player") as Node3D
 if OS.has_feature("mobile"):
  Engine.max_fps=mobile_target_fps
 _update_wanted()

func focus_position() -> Vector3:
 return player.global_position if is_instance_valid(player) else Vector3(-341,1,154)

func cell_center(key: Vector2i) -> Vector2:
 return Vector2(-500+(key.x+.5)*cell_size,-250+(key.y+.5)*cell_size)

func cell_path(key: Vector2i) -> String:
 return cells_directory.path_join("cell_%02d_%02d.scn" % [key.x,key.y])

func _update_wanted() -> void:
 var at := Vector2(focus_position().x,focus_position().z)
 wanted.clear()
 for key in available_cells:
  if cell_center(key).distance_to(at)<=load_radius+cell_size*.71:
   wanted.append(key)
 wanted.sort_custom(func(a: Vector2i,b: Vector2i)->bool:return cell_center(a).distance_squared_to(at)<cell_center(b).distance_squared_to(at))
 if wanted.size()>maximum_cells:wanted.resize(maximum_cells)
 for key in loaded.keys():
  if cell_center(key).distance_to(at)>unload_radius or (not wanted.has(key) and loaded.size()>=maximum_cells):
   loaded[key].queue_free()
   loaded.erase(key)

func _process(delta: float) -> void:
 clock-=delta
 if clock<=0:
  clock=.25
  _update_wanted()
 var started := Time.get_ticks_usec()
 for key in pending.keys():
  var path: String=pending[key]
  var status := ResourceLoader.load_threaded_get_status(path)
  if status==ResourceLoader.THREAD_LOAD_LOADED:
   var packed := ResourceLoader.load_threaded_get(path) as PackedScene
   pending.erase(key)
   if wanted.has(key) and packed!=null and loaded.size()<maximum_cells:
    var before := Time.get_ticks_usec()
    var cell := packed.instantiate()
    add_child(cell)
    loaded[key]=cell
    peak_instantiation_ms=maxf(peak_instantiation_ms,(Time.get_ticks_usec()-before)/1000.0)
    peak_cells=maxi(peak_cells,loaded.size())
   if (Time.get_ticks_usec()-started)/1000.0>=instantiate_budget_ms:break
  elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
   pending.erase(key)
   requests_failed+=1
 for key in wanted:
  if pending.size()>=maximum_inflight or loaded.size()+pending.size()>=maximum_cells:break
  if loaded.has(key) or pending.has(key):continue
  var path := cell_path(key)
  if ResourceLoader.load_threaded_request(path,"PackedScene",false)==OK:pending[key]=path
  else:requests_failed+=1

func stats() -> Dictionary:
 return {"loaded":loaded.size(),"pending":pending.size(),"peak_cells":peak_cells,"peak_instantiate_ms":peak_instantiation_ms,"failed":requests_failed}
