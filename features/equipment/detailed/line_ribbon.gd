@tool
extends MeshInstance3D

@export_node_path("Node3D") var start_anchor: NodePath
@export_node_path("Node3D") var end_anchor: NodePath
@export_node_path("Camera3D") var camera_path: NodePath
@export_range(0.0001, 0.004, 0.00005) var width: float = 0.0007
@export_range(0.0001, 0.004, 0.00005) var maximum_width: float = 0.0012
@export_range(0.0, 2.0, 0.05) var minimum_pixel_width: float = 0.85
@export_range(0.0, 0.15, 0.001) var slack: float = 0.0
@export_range(2, 16, 1) var curved_segments: int = 8
@export var control_points: PackedVector3Array = PackedVector3Array()
var rendered_triangles: int = 0
var endpoint_error: float = 0.0

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): refresh()

func refresh() -> void:
	var start := get_node_or_null(start_anchor) as Node3D
	var end := get_node_or_null(end_anchor) as Node3D
	var camera := get_node_or_null(camera_path) as Camera3D
	if start == null or end == null or camera == null:
		return
	var anchors: PackedVector3Array = control_points
	if anchors.size() < 2:
		anchors = PackedVector3Array([start.global_position, end.global_position])
	visible = true
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	var subdivisions := 1 if slack < 0.000001 else curved_segments
	for span in range(anchors.size() - 1):
		var a: Vector3 = anchors[span]
		var b: Vector3 = anchors[span + 1]
		var sag := minf(slack, a.distance_to(b) * 0.2)
		for j in range(subdivisions):
			var t := float(j) / subdivisions
			points.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	points.append(anchors[-1])
	var count := points.size() - 1
	var length := 0.0
	for i in range(count):
		length += points[i].distance_to(points[i + 1])
	for i in range(count):
		var p := points[i]
		var q := points[i + 1]
		var tangent := (q - p).normalized()
		var sides: Array[Vector3] = []
		for center in [p, q]:
			var toward_camera: Vector3 = (camera.global_position - center).normalized()
			var side := tangent.cross(toward_camera)
			if side.length_squared() < 0.0000001:
				side = camera.global_basis.x - tangent * camera.global_basis.x.dot(tangent)
			if side.length_squared() < 0.0000001:
				side = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT)
			var viewport_height := maxf(1.0, camera.get_viewport().get_visible_rect().size.y)
			var pixel_width: float = camera.size / viewport_height if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else 2.0 * camera.global_position.distance_to(center) * tan(deg_to_rad(camera.fov) * 0.5) / viewport_height
			sides.append(side.normalized() * minf(maxf(width, pixel_width * minimum_pixel_width), maximum_width) * 0.5)
		var corners := [p - sides[0], p + sides[0], q + sides[1], q - sides[1]]
		var uv := [Vector2(0, float(i) / count * length * 80.0), Vector2(1, float(i) / count * length * 80.0), Vector2(1, float(i + 1) / count * length * 80.0), Vector2(0, float(i + 1) / count * length * 80.0)]
		for k in [0, 1, 2, 0, 2, 3]:
			tool.set_uv(uv[k])
			tool.set_normal((camera.global_position - corners[k]).normalized())
			tool.add_vertex(to_local(corners[k]))
	mesh = tool.commit()
	rendered_triangles = count * 2
	endpoint_error = 0.0
	for i in range(anchors.size()):
		endpoint_error = maxf(endpoint_error, points[i * subdivisions].distance_to(anchors[i]))

