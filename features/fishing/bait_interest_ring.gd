extends Node3D
@export var waiting_color:=Color(.4,.78,1,.8)
@export var interested_color:=Color(1,.8,.22,.9)
@export var committed_color:=Color(1,.3,.2,.95)
@export_range(.6,5.0,.1) var scan_period:=2.4
var phase:="waiting"
var radius_m:=4.5
var interested_count:=0
func present(status:Dictionary,point:Vector3,surface_height:float)->void:
 visible=status.active
 if not visible:return
 global_position=Vector3(point.x,surface_height+.06,point.z)
 phase=status.phase;radius_m=status.radius_m;interested_count=status.interested_count
 $Ring.scale=Vector3(radius_m,1,radius_m)
 var mat:ShaderMaterial=$Ring.material_override
 mat.set_shader_parameter("radius_m",radius_m)
 mat.set_shader_parameter("ring_color",committed_color if phase=="committed" else interested_color if phase=="interested" else waiting_color)
 mat.set_shader_parameter("committed",1.0 if phase=="committed" else 0.0)
 mat.set_shader_parameter("scan_period",scan_period)
