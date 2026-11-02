class_name LocalMinimapView
extends Control
## Lightweight local projection: no extra 3D viewport or all-map pan clamp.
@export var map_data: FishingMapDefinition
@export_range(10.0, 200.0) var radius_m := 100.0
var player_position := Vector2.ZERO
var player_yaw := 0.0
var fish_positions := PackedVector2Array()
var favorites: Array = []
var target: Dictionary = {}
var marker_alpha := 1.0
var pulse_progress := -1.0

func _ready() -> void:
	resized.connect(_sync_materials)
	configure(map_data)

func configure(value: FishingMapDefinition) -> void:
	map_data = value
	if value != null:
		$Terrain.texture = value.texture
	_sync_materials()

func set_history(_records: Array, spots: Array) -> void:
	favorites = spots
	queue_redraw()

func set_player(position_xz: Vector2, yaw: float) -> void:
	player_position = position_xz
	player_yaw = yaw
	_sync_materials()

func project(point: Vector2) -> Vector2:
	return size * 0.5 + (point - player_position) * (minf(size.x,size.y) * 0.5 / radius_m)

func in_range(point: Vector2) -> bool:
	return point.is_finite() and point.distance_squared_to(player_position) <= radius_m * radius_m

func _sync_materials() -> void:
	if not is_node_ready(): return
	var terrain_material: ShaderMaterial = $Terrain.material
	if map_data != null:
		terrain_material.set_shader_parameter("player_uv",(player_position-map_data.bounds.position)/map_data.bounds.size)
		terrain_material.set_shader_parameter("span_uv",Vector2.ONE*radius_m*2.0/map_data.bounds.size)
	(material as ShaderMaterial).set_shader_parameter("view_size",size)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x,size.y) * 0.5
	for spot in favorites:
		var point: Vector2 = spot.position
		if in_range(point):
			draw_circle(project(point),3.0,Color(0.97,0.78,0.30))
	if not target.is_empty() and in_range(target.position):
		draw_circle(project(target.position),7.0,Color(1,0.85,0.38),false,1.5,true)
	if pulse_progress >= 0 and pulse_progress < 1:
		draw_circle(center,maxf(1.0,radius*pulse_progress),Color(1,0.94,0.68,(1.0-pulse_progress)*0.8),false,1.5,true)
	for position_xz in fish_positions:
		if in_range(position_xz):
			var at := project(position_xz)
			draw_circle(at,3.8,Color(0.08,0.025,0.02,marker_alpha))
			draw_circle(at,2.7,Color(1.0,0.12,0.13,marker_alpha))
	# A fixed center anchor; only the arrow heading rotates. North remains up.
	var direction := Vector2(-sin(player_yaw),-cos(player_yaw))
	var side := direction.orthogonal()
	var outline := PackedVector2Array([center+direction*12.0,center-direction*8.0+side*8.0,center-direction*4.0,center-direction*8.0-side*8.0])
	var arrow := PackedVector2Array([center+direction*8.0,center-direction*5.0+side*4.5,center-direction*2.0,center-direction*5.0-side*4.5])
	draw_colored_polygon(outline,Color(0.03,0.035,0.025))
	draw_colored_polygon(arrow,Color(1,0.98,0.89))
