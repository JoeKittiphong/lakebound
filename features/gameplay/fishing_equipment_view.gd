class_name FishingEquipmentView
extends Node3D
## Camera-local equipment, separate from the third person skeleton/hand animation.
@export var player: AnglerPlayer
@export var controller: FishingController
@export var pump_degrees: float = 12.0
@export_range(0.0, 70.0) var lateral_yaw_degrees: float = 42.0
@export_range(0.05, 0.5) var input_smooth_time: float = 0.14
@export_range(0.05, 0.5) var return_smooth_time: float = 0.20
@export var pull_follow_speed: float = 9.0
@onready var handle_anchor: Marker3D = $HandleAnchor
@onready var socket: Node3D = $Socket
@onready var rod: FishingRodVisual = $Socket/Rod
var active: bool = false
var _rod_scene: PackedScene
var _socket_rest: Vector3
var _smooth_load: float = 0.0
var visual_stick := Vector2.ZERO
var stick_velocity := Vector2.ZERO
var smooth_pull := Vector3.FORWARD
func _ready() -> void:
 _socket_rest = socket.rotation
 _rod_scene = load(rod.scene_file_path)
 hide()
func set_active(value: bool) -> void:
 active = value
 visible = value
 if not is_instance_valid(player): return
 player.character_model.first_person = value
 player.character_model.get_node("Asset").visible = not value
 if not value:
  player.first_person_rod = null
  player.character_model.first_person_rod = null
 else:
  visual_stick = Vector2.ZERO
  stick_velocity = Vector2.ZERO
  sync_equipment()
  smooth_pull = -global_basis.z.normalized()
  player.first_person_rod = rod if player.character_model.rod_mesh != null else null
func sync_equipment() -> void:
 if not is_instance_valid(player): return
 var source := player.character_model.rod_mesh as FishingRodVisual
 rod.visible = source != null
 if source == null:
  player.first_person_rod = null
  player.character_model.first_person_rod = null
  return
 var selected := load(source.scene_file_path) as PackedScene
 if selected != _rod_scene:
  socket.remove_child(rod)
  rod.queue_free()
  rod = selected.instantiate() as FishingRodVisual
  socket.add_child(rod)
  _rod_scene = selected
 rod.set_held_reel(source._held_scene, source._spool_axis)
 rod.set_line_attached(source.line_attached)
 if rod is DetailedFishingRod and source is DetailedFishingRod and rod.line_style != source.line_style: rod.set_line_style(source.line_style)
 player.first_person_rod = rod if active else null
 player.character_model.first_person_rod = player.first_person_rod
func _process(delta: float) -> void:
 if not active or not is_instance_valid(controller) or not is_instance_valid(player): return
 sync_equipment()
 if player.character_model.rod_mesh == null: return
 update_rod_pose(delta, controller.rod_input)
 var desired := controller.tension if controller.state == FishingController.State.FIGHT else 0.03
 var response_seconds := 0.1
 if rod is DetailedFishingRod and rod.rod_spec != null:
  response_seconds = rod.rod_spec.recovery_seconds if desired < _smooth_load else rod.rod_spec.recovery_seconds * 0.65
 _smooth_load = lerpf(_smooth_load, desired, 1.0 - exp(-delta / response_seconds))
 var target := controller.cast_position
 target.y = -0.18 - controller.cast_position.y
 if controller.state == FishingController.State.FIGHT and controller.active_fish != null:
  target = controller.active_fish.position
  target.y = -0.18 - controller.active_fish.position.y
 var direction := (target - rod.tip.global_position).normalized()
 smooth_pull = smooth_pull.lerp(direction, 1.0 - exp(-pull_follow_speed * delta)).normalized()
 if rod is DetailedFishingRod:
  rod.set_pull_direction(smooth_pull)
 rod.set_load(_smooth_load, visual_stick.x)
 if rod is DetailedFishingRod:
  rod.payout_amount = maxf(0.0, controller.fish_force - controller.drag_strength) if controller.state == FishingController.State.FIGHT else 0.0
  if controller.profile != null:
   var capacity := controller.profile.line_capacity()
   rod.fill_fraction = clampf((minf(controller.profile.data.line_remaining, capacity) - controller.line_length) / maxf(1.0, capacity), 0.05, 1.0)
 rod.advance_reel(delta, maxf(0.0, controller.rod_input.y))
 if rod is DetailedFishingRod: rod.update_guides()
 player._sync_rod_tip()

func update_rod_pose(delta: float, command: Vector2) -> void:
 # Exact critically damped response: release preserves velocity without an overshoot spring.
 var duration := return_smooth_time if command.length_squared() < 0.0001 else input_smooth_time
 var omega := 2.0 / duration
 var offset := visual_stick - command
 var impulse := stick_velocity + omega * offset
 var decay := exp(-omega * delta)
 visual_stick = command + (offset + impulse * delta) * decay
 stick_velocity = (stick_velocity - omega * impulse * delta) * decay
 socket.rotation = _socket_rest + Vector3(deg_to_rad(pump_degrees) * visual_stick.y, -deg_to_rad(lateral_yaw_degrees) * visual_stick.x, -visual_stick.x * 0.22)
 # The actual butt end stays at the camera-local anchor while the shaft sweeps.
 var pivot := Vector3.ZERO
 if rod is DetailedFishingRod: pivot = Vector3(0, -float(rod.config["grip_x"]), 0)
 socket.position = handle_anchor.position - socket.basis * pivot
