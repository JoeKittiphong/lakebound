extends Node3D

## Position-based contact effects; independent of character meshes and bones.
@export var player: Node3D
@export var pond: Pond
@export var ecosystem: PondEcosystem
@export var water_surface: MeshInstance3D
@export var water_height: float = -0.18
@export_range(0.05, 0.5) var sample_interval: float = 0.1
@export_range(10.0, 80.0) var effect_distance: float = 45.0
@export_range(0.05, 0.5) var fish_surface_depth: float = 0.22
@export_range(0.3, 2.0) var fish_repeat_seconds: float = 1.2
@export_range(0.1, 1.0) var step_distance: float = 0.48
@export_range(1.0, 4.0) var ripple_lifetime: float = 2.6
@export_group("Surface response")
@export var enable_surface_displacement := true
## Keep enabled on Mobile. A CPU fallback supports headless QA and Compatibility.
@export var use_gpu_field := true
@export_range(128, 256, 128) var field_resolution: int = 256
@export_range(24.0, 64.0) var field_span: float = 48.0
@export_range(0.03, 0.15) var field_update_interval: float = 0.05
@export_range(0.01, 0.1) var wave_amplitude: float = 0.06
@export_range(0.5, 2.0) var wavelength: float = 1.1
@export_range(0.5, 3.0) var wave_speed: float = 1.55
const MAX_EVENTS := 12
const NEUTRAL := 128.0 / 255.0
const PACKET_WIDTH := 0.65
const PACKET_SUPPORT := PACKET_WIDTH * 2.8
@onready var surface_detail: MeshInstance3D = $SurfaceDetail
var water_material: ShaderMaterial
var detail_material: ShaderMaterial
var field_texture: Texture2D
var field_image: Image
@onready var field_viewport: SubViewport = $FieldViewport
@onready var field_stamps: MultiMeshInstance2D = $FieldViewport/WaveStamps
var _using_gpu_field := false
var _gpu_field_had_waves := false
var field_clock := 0.0
var active_event_count := 0
var _field_was_active := false
var _slopes_x := PackedFloat32Array()
var _slopes_z := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _pixels := PackedByteArray()
var _marks := PackedInt32Array()
var _touched := PackedInt32Array()
var _touched_count := 0
var _generation := 0
var _profile_height := PackedFloat32Array()
var _profile_slope := PackedFloat32Array()
var _profile_step := 0.0
var _profile_wavelength := 0.0
var _last_center := Vector2(INF, INF)
var _last_span := 0.0
var _shader_field_active := false
var event_positions: Array[Vector2] = []
var clock := 0.0
var sample_clock := 0.0
var cursor := 0
var events: Array[Vector3] = [] # birth time, strength, variation
var fish_contacts: Dictionary = {}
var was_in_water := false
var previous_player_position := Vector3.ZERO
var step_travel := 0.0
var emitted_count := 0

func _ready() -> void:
 events.resize(MAX_EVENTS)
 event_positions.resize(MAX_EVENTS)
 for i in events.size():
  events[i] = Vector3(-100.0, 0.0, 0.0)
 if is_instance_valid(water_surface):
  var source := water_surface.get_active_material(0) as ShaderMaterial
  if source != null:
   water_material = source.duplicate() as ShaderMaterial
   detail_material = source.duplicate() as ShaderMaterial
   _using_gpu_field = use_gpu_field and RenderingServer.get_rendering_device() != null
   if _using_gpu_field:
    field_viewport.size = Vector2i.ONE * field_resolution
    $FieldViewport/Neutral.size = Vector2.ONE * field_resolution
    var template := field_stamps.multimesh
    var stamps := MultiMesh.new()
    stamps.transform_format = MultiMesh.TRANSFORM_2D
    stamps.use_custom_data = true
    stamps.mesh = template.mesh
    stamps.instance_count = MAX_EVENTS
    stamps.visible_instance_count = 0
    field_stamps.multimesh = stamps
    field_texture = field_viewport.get_texture()
    field_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
   else:
    field_image = Image.create(field_resolution, field_resolution, false, Image.FORMAT_RGBA8)
    field_image.fill(Color(NEUTRAL, NEUTRAL, NEUTRAL, 1))
    field_texture = ImageTexture.create_from_image(field_image)
    _initialize_buffers()
   water_surface.material_override = water_material
   surface_detail.material_override = detail_material
   detail_material.set_shader_parameter("is_detail_patch", true)
   surface_detail.visible = enable_surface_displacement
   for material in [water_material, detail_material]:
    material.set_shader_parameter("interaction_enabled", true)
    material.set_shader_parameter("interaction_field_active", false)
    material.set_shader_parameter("detail_patch_enabled", enable_surface_displacement)
    material.set_shader_parameter("detail_patch_half_size", (surface_detail.mesh as PlaneMesh).size.x * 0.5)
    material.set_shader_parameter("interaction_field", field_texture)
    material.set_shader_parameter("interaction_neutral", 0.5 if _using_gpu_field else NEUTRAL)
   _update_field()
  else:
   surface_detail.hide()
 else:
  surface_detail.hide()
 if is_instance_valid(player):
  previous_player_position = player.global_position

func emit_ripple(point: Vector3, strength: float = 1.0) -> void:
 if events.is_empty():
  return
 if is_instance_valid(player) and Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length_squared() > effect_distance * effect_distance:
  return
 var slot := cursor
 cursor = (cursor + 1) % events.size()
 events[slot] = Vector3(clock, clampf(strength, 0.0, 1.5), fposmod(float(emitted_count) * 0.618, 1.0))
 event_positions[slot] = Vector2(point.x, point.z)
 emitted_count += 1

func _process(delta: float) -> void:
 clock += delta
 sample_clock += delta
 if sample_clock >= sample_interval:
  sample_clock = 0.0
  _sample_contacts()
 field_clock += delta
 if field_clock >= field_update_interval:
  field_clock = 0.0
  _update_field()

func _update_field() -> void:
 if _using_gpu_field:
  _update_gpu_field()
  return
 if field_image == null or not is_instance_valid(player):
  return
 # Keep full-resolution surface detail, but reuse work buffers and a shared
 # radial kernel. Only touched annulus pixels are cleared, accumulated/encoded.
 var cell := field_span / float(field_resolution)
 var center := Vector2(snappedf(player.global_position.x, cell), snappedf(player.global_position.z, cell))
 var origin := center - Vector2.ONE * field_span * 0.5
 active_event_count = 0
 for event in events:
  var age := clock - event.x
  if age >= 0.0 and age < ripple_lifetime and event.y > 0.0:
   active_event_count += 1
 if active_event_count == 0:
  if _field_was_active:
   _clear_touched()
   _upload_field()
  _field_was_active = false
  _set_field_active(false)
  _move_field_region(center, origin)
  return
 var previously_touched := _touched_count > 0
 _clear_touched()
 _generation += 1
 _ensure_kernel(cell * 0.25)
 var bounds := Rect2i()
 for i in events.size():
  var age := clock - events[i].x
  if age < 0.0 or age >= ripple_lifetime or events[i].y <= 0.0:
   continue
  var position_on_grid := (event_positions[i] - origin) / cell
  var radius := wave_speed * age
  var support := radius + PACKET_SUPPORT
  var lo := Vector2i(floori(position_on_grid.x - support / cell), floori(position_on_grid.y - support / cell)).clamp(Vector2i.ZERO, Vector2i.ONE * field_resolution)
  var hi := Vector2i(ceili(position_on_grid.x + support / cell), ceili(position_on_grid.y + support / cell)).clamp(Vector2i.ZERO, Vector2i.ONE * field_resolution)
  if hi.x <= lo.x or hi.y <= lo.y:
   continue
  var stamp_bounds := Rect2i(lo, hi - lo)
  bounds = stamp_bounds if bounds.size == Vector2i.ZERO else bounds.merge(stamp_bounds)
  var fade := smoothstep(0.0, 0.10, age) * pow(1.0 - age / ripple_lifetime, 1.5)
  var amplitude := wave_amplitude * events[i].y * fade / sqrt(1.0 + radius)
  if amplitude < 0.0001:
   continue
  var inner_radius := maxf(0.0, radius - PACKET_SUPPORT)
  var outer_squared := support * support
  var inner_squared := inner_radius * inner_radius
  var last_profile := _profile_height.size() - 2
  for z in range(lo.y, hi.y):
   var dz := (float(z) + 0.5 - position_on_grid.y) * cell
   var dz_squared := dz * dz
   if dz_squared >= outer_squared:
    continue
   var outer_x := sqrt(outer_squared - dz_squared) / cell
   var left := maxi(lo.x, ceili(position_on_grid.x - outer_x - 0.5))
   var right := mini(hi.x, floori(position_on_grid.x + outer_x - 0.5) + 1)
   if left >= right:
    continue
   var has_inner := dz_squared < inner_squared
   var inner_left := right
   var inner_right := right
   if has_inner:
    var inner_x := sqrt(inner_squared - dz_squared) / cell
    inner_left = clampi(ceili(position_on_grid.x - inner_x - 0.5), left, right)
    inner_right = clampi(floori(position_on_grid.x + inner_x - 0.5) + 1, left, right)
   for half in (2 if has_inner else 1):
    var start_x := left if half == 0 else inner_right
    var end_x := inner_left if half == 0 else right
    var dx := (float(start_x) + 0.5 - position_on_grid.x) * cell
    var row_index := z * field_resolution
    for x in range(start_x, end_x):
     var distance := sqrt(dx * dx + dz_squared)
     if distance >= 0.01:
      var lookup := (distance - radius + PACKET_SUPPORT) / _profile_step
      var sample_index := clampi(int(lookup), 0, last_profile)
      var fraction := clampf(lookup - float(sample_index), 0.0, 1.0)
      var height := lerpf(_profile_height[sample_index], _profile_height[sample_index + 1], fraction) * amplitude
      var gradient := lerpf(_profile_slope[sample_index], _profile_slope[sample_index + 1], fraction) * amplitude / distance
      var index := row_index + x
      if _marks[index] != _generation:
       _marks[index] = _generation
       _touched[_touched_count] = index
       _touched_count += 1
      _heights[index] += height
      _slopes_x[index] -= gradient * dx
      _slopes_z[index] -= gradient * dz
     dx += cell
 for n in _touched_count:
  var index := _touched[n]
  var byte := index * 4
  _pixels[byte] = clampi(roundi(128.0 + _slopes_x[index] * 127.5), 0, 255)
  _pixels[byte + 1] = clampi(roundi(128.0 + _slopes_z[index] * 127.5), 0, 255)
  _pixels[byte + 2] = clampi(roundi(128.0 + _heights[index] * 637.5), 0, 255)
 _field_was_active = _touched_count > 0
 if previously_touched or _field_was_active:
  _upload_field()
 _set_field_active(_field_was_active)
 if _field_was_active:
  var uv_bounds := Vector4(float(bounds.position.x) / field_resolution, float(bounds.position.y) / field_resolution, float(bounds.end.x) / field_resolution, float(bounds.end.y) / field_resolution)
  for material in [water_material, detail_material]:
   material.set_shader_parameter("interaction_uv_bounds", uv_bounds)
 _move_field_region(center, origin)

func _initialize_buffers() -> void:
 var count := field_resolution * field_resolution
 _slopes_x.resize(count)
 _slopes_z.resize(count)
 _heights.resize(count)
 _marks.resize(count)
 _touched.resize(count)
 _pixels = field_image.get_data()
 _ensure_kernel(field_span / float(field_resolution) * 0.25)

func _ensure_kernel(step_size: float) -> void:
 if _profile_step == step_size and _profile_wavelength == wavelength:
  return
 _profile_step = step_size
 _profile_wavelength = wavelength
 var count := ceili(PACKET_SUPPORT * 2.0 / step_size) + 2
 _profile_height.resize(count)
 _profile_slope.resize(count)
 var k := TAU / wavelength
 for i in count:
  var offset := float(i) * step_size - PACKET_SUPPORT
  var q := offset / PACKET_WIDTH
  var phase := k * offset
  var envelope := exp(-0.5 * q * q)
  _profile_height[i] = envelope * sin(phase)
  _profile_slope[i] = envelope * (k * cos(phase) - q / PACKET_WIDTH * sin(phase))

func _clear_touched() -> void:
 for n in _touched_count:
  var index := _touched[n]
  _slopes_x[index] = 0.0
  _slopes_z[index] = 0.0
  _heights[index] = 0.0
  var byte := index * 4
  _pixels[byte] = 128
  _pixels[byte + 1] = 128
  _pixels[byte + 2] = 128
 _touched_count = 0

func _upload_field() -> void:
 field_image.set_data(field_resolution, field_resolution, false, Image.FORMAT_RGBA8, _pixels)
 (field_texture as ImageTexture).update(field_image)

func _update_gpu_field() -> void:
 if not is_instance_valid(player):
  return
 var cell := field_span / float(field_resolution)
 var center := Vector2(snappedf(player.global_position.x, cell), snappedf(player.global_position.z, cell))
 var origin := center - Vector2.ONE * field_span * 0.5
 var bounds := Rect2()
 var visible := 0
 active_event_count = 0
 for i in MAX_EVENTS:
  var age := clock - events[i].x
  if age < 0.0 or age >= ripple_lifetime or events[i].y <= 0.0:
   continue
  active_event_count += 1
  var radius := wave_speed * age
  var support := radius + PACKET_SUPPORT
  var position_on_grid := (event_positions[i] - origin) / cell
  var stamp := Rect2(position_on_grid - Vector2.ONE * support / cell, Vector2.ONE * support * 2.0 / cell)
  var clipped := stamp.intersection(Rect2(Vector2.ZERO, Vector2.ONE * field_resolution))
  if not clipped.has_area():
   continue
  var fade := smoothstep(0.0, 0.10, age) * pow(1.0 - age / ripple_lifetime, 1.5)
  var amplitude := wave_amplitude * events[i].y * fade / sqrt(1.0 + radius)
  if amplitude < 0.0001:
   continue
  field_stamps.multimesh.set_instance_transform_2d(visible, Transform2D(0.0, Vector2.ONE * support / cell, 0.0, position_on_grid))
  field_stamps.multimesh.set_instance_custom_data(visible, Color(radius, amplitude, wavelength, 1))
  visible += 1
  bounds = clipped if not bounds.has_area() else bounds.merge(clipped)
 field_stamps.multimesh.visible_instance_count = visible
 if visible > 0 or _gpu_field_had_waves:
  # 2D-only 256px data target; never render the river or read pixels on the CPU.
  field_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
 _gpu_field_had_waves = visible > 0
 _set_field_active(visible > 0)
 if visible > 0:
  var uv_bounds := Vector4(bounds.position.x / field_resolution, bounds.position.y / field_resolution, bounds.end.x / field_resolution, bounds.end.y / field_resolution)
  for material in [water_material, detail_material]:
   material.set_shader_parameter("interaction_uv_bounds", uv_bounds)
 _move_field_region(center, origin)

## Diagnostic readback only. Production rendering uses field_texture directly.
## Call after frame_post_draw when the GPU path is enabled.
func get_field_image() -> Image:
 if not _using_gpu_field:
  return field_image
 var result := field_viewport.get_texture().get_image()
 result.convert(Image.FORMAT_RGBAF)
 var values := result.get_data().to_float32_array()
 var bytes := PackedByteArray()
 bytes.resize(field_resolution * field_resolution * 4)
 for i in range(0, bytes.size(), 4):
  for channel in 3:
   bytes[i + channel] = clampi(roundi(128.0 + (values[i + channel] - 0.5) * 255.0), 0, 255)
  bytes[i + 3] = 255
 return Image.create_from_data(field_resolution, field_resolution, false, Image.FORMAT_RGBA8, bytes)

func _set_field_active(value: bool) -> void:
 if value == _shader_field_active:
  return
 _shader_field_active = value
 for material in [water_material, detail_material]:
  material.set_shader_parameter("interaction_field_active", value)

func _move_field_region(center: Vector2, origin: Vector2) -> void:
 if center == _last_center and field_span == _last_span:
  return
 _last_center = center
 _last_span = field_span
 var rectangle := Vector4(origin.x, origin.y, field_span, field_span)
 for material in [water_material, detail_material]:
  material.set_shader_parameter("interaction_rect", rectangle)
  material.set_shader_parameter("detail_patch_center", center)
 surface_detail.global_position = Vector3(center.x, water_height, center.y)

func _sample_contacts() -> void:
 if not is_instance_valid(player) or not is_instance_valid(pond):
  return
 var point := player.global_position
 var in_water: bool = pond.definition.is_wading(point) or (player is AnglerPlayer and player.swimming)
 if player is AnglerPlayer and player.boat != null:
  point = player.boat.global_position + player.boat.global_basis.z * 2.6
  in_water = true
 # A bridge/jetty above water must never produce footsteps on the water.
 if in_water:
  if not was_in_water:
   emit_ripple(point, 1.0)
   step_travel = 0.0
  else:
   var movement := Vector2(point.x - previous_player_position.x, point.z - previous_player_position.z).length()
   # Ignore teleports; avoid creating a trail across the map.
   if movement < 2.0:
    step_travel += movement
   if step_travel >= step_distance:
    emit_ripple(point, 0.7)
    step_travel = 0.0
 elif was_in_water:
  emit_ripple(previous_player_position, 0.6)
  step_travel = 0.0
 was_in_water = in_water
 previous_player_position = point
 if not is_instance_valid(ecosystem):
  return
 var live_ids := {}
 for fish in ecosystem.fish:
  live_ids[fish.id] = true
  if fish.state == &"landed":
   fish_contacts.erase(fish.id)
   continue
  var near_surface: bool = fish.position.y <= fish_surface_depth
  var contact: Vector4 = fish_contacts.get(fish.id, Vector4(0, -100, fish.position.x, fish.position.z))
  var travel := Vector2(fish.position.x - contact.z, fish.position.z - contact.w).length_squared()
  if near_surface and (contact.x < 0.5 or (clock - contact.y >= fish_repeat_seconds and travel > 0.04)):
   emit_ripple(fish.position, 1.0 if contact.x < 0.5 else 0.55)
   contact.y = clock
   contact.z = fish.position.x
   contact.w = fish.position.z
  # Hysteresis prevents a fish bobbing on the threshold from spamming events.
  if near_surface:
   contact.x = 1.0
  elif fish.position.y > fish_surface_depth + 0.15:
   contact.x = 0.0
  fish_contacts[fish.id] = contact
 for identity in fish_contacts.keys():
  if not live_ids.has(identity):
   fish_contacts.erase(identity)
