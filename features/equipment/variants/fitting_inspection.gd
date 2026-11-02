extends Node3D
@export_range(0.0,1.0) var preview_load: float = 0.7
@export var retrieving: bool = true
@onready var rod: DetailedFishingRod = $Rod
@onready var camera: Camera3D = $Camera3D
func _ready() -> void: focus("full")
func show_item(id: String) -> void:
 var item := TackleCatalog.item(id)
 remove_child(rod);rod.queue_free()
 rod=item.model_scene.instantiate() as DetailedFishingRod
 rod.name="Rod";rod.rotation.z=-PI*.5;add_child(rod)
 rod.set_pull_direction(Vector3.FORWARD);rod.set_load(preview_load,0)
 $Labels/Name.text=item.display_name+"  |  "+EquipmentFit.layout_label(item.mount_layout)
 focus("full")
func _process(delta: float) -> void:
 rod.set_pull_direction(Vector3.FORWARD)
 rod.set_load(preview_load,0)
 if retrieving:rod.advance_reel(delta,.25)
 rod.update_guides()
func focus(mode: String) -> void:
 rod.update_guides()
 var at := rod.global_position.lerp(rod.tip.global_position,.45)
 var offset := Vector3(.4,-2.7,1.1)
 camera.size=float(rod.config.length)*.8
 if mode=="seat":
  at=rod.get_node("ReelMount").global_position+Vector3(.02,0,-.025 if rod.config.layout!="casting" else .025)
  offset=Vector3(.12,-.20,.12);camera.size=.22
 elif mode=="guide" and not rod.guide_points.is_empty():
  at=rod.guide_points[0];offset=Vector3(.14,-.07,.035)
  camera.size=rod.guide_frame(rod.config.guides[0]).basis.x.length()*2.0
 camera.global_position=at+offset;camera.look_at(at)
 $Labels/Info.text="Load %.0f%%  |  %s  |  %s" % [preview_load*100,mode,"reel / guide train / tip"]
