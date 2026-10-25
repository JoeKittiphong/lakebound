extends Node3D

const FishVisual = preload("res://world/pond/fish_visual.tscn")
@export var controller: FishingController
@export var player: Node3D
@export var ecosystem: PondEcosystem
@export var rod_tip: Node3D
@export var audio_enabled := true
@export_range(1.0, 8.0) var visible_fish_depth: float = 5.0
@export var water_height: float = -0.18
@onready var line_mesh: ImmediateMesh = $Line.mesh
var visual_pool: Array[Node3D] = []
var update_clock := 0.0
var time := 0.0

func _ready() -> void:
 for index in 7:
  var visual := FishVisual.instantiate() as Node3D
  $FishVisuals.add_child(visual)
  visual.hide()
  visual_pool.append(visual)
 controller.bite_notified.connect(_on_bite)
 controller.fish_landed.connect(_on_landed)

func _on_bite() -> void:
 if audio_enabled:
  $BiteAudio.play()

func _on_landed(_fish: RefCounted) -> void:
 if audio_enabled:
  $SplashAudio.play()

func _exit_tree() -> void:
 $BiteAudio.stop()
 $ReelAudio.stop()
 $SplashAudio.stop()

func _process(delta: float) -> void:
 if not is_instance_valid(controller) or not is_instance_valid(player):
  return
 time += delta
 var state: int = controller.state
 var working_reel: bool = audio_enabled and state in [controller.State.WAITING, controller.State.BITE, controller.State.FIGHT] and absf(controller.rod_input.y) > 0.15
 if working_reel:
  $ReelAudio.pitch_scale = 0.8 + controller.fish_force * 0.4
  if not $ReelAudio.playing:
   $ReelAudio.play()
 else:
  $ReelAudio.stop()
 var ready_state: bool = state == controller.State.READY
 var line_visible: bool = state in [controller.State.WAITING, controller.State.BITE, controller.State.FIGHT, controller.State.CASTING]
 $AimMarker.visible = ready_state and (not player is AnglerPlayer or player.can_fish())
 $Bobber.visible = state in [controller.State.WAITING, controller.State.BITE, controller.State.CASTING]
 $Ripple.visible = line_visible
 var target: Vector3 = controller.get_aim_position()
 target.y = -0.13
 if not ready_state:
  target = Vector3(controller.cast_position.x, -0.12, controller.cast_position.z)
 if state == controller.State.FIGHT and controller.active_fish != null:
  target = Vector3(controller.active_fish.position.x, -0.12, controller.active_fish.position.z)
 var lure: bool = controller.using_lure()
 $LureVisual.visible = lure and state in [controller.State.WAITING, controller.State.BITE, controller.State.CASTING]
 if lure and line_visible:
  $Bobber.hide()
  target.y = water_height - controller.cast_position.y
 if controller.profile != null and state == controller.State.FIGHT and controller.active_fish != null:
  target.y = water_height - controller.active_fish.position.y
 if state == controller.State.CASTING:
  var fraction: float = controller.cast_progress()
  target = (player.global_position + Vector3(0.4, 1.7, 0)).lerp(target, fraction)
  target.y += sin(fraction * PI) * 2.5
 $AimMarker.global_position = Vector3(target.x, -0.12, target.z)
 $Bobber.global_position = target + Vector3(0, sin(time * 3.0) * 0.045, 0)
 if $LureVisual.visible:
  $LureVisual.global_position = target
  var motion: String = controller.profile.equipped("bait").motion
  $LureVisual/Minnow.visible = motion == "swim"
  $LureVisual/Frog.visible = motion == "float"
  $LureVisual/SoftPlastic.visible = motion == "sink"
  var heading := player.global_position - target
  $LureVisual.rotation.y = atan2(-heading.x, -heading.z)
  $LureVisual.rotation.z = sin(time * 10.0) * 0.15 if controller.lure_holding else 0.0
 if state == controller.State.BITE:
  $Bobber.global_position.y -= absf(sin(time * 15.0)) * 0.35
 $Ripple.global_position = Vector3(target.x, -0.12, target.z)
 if lure and target.y < water_height - 0.35:
  $Ripple.hide()
 if state == controller.State.CASTING:
  $Ripple.hide()
 $Ripple.scale = Vector3.ONE * (0.8 + fmod(time * 0.6, 1.0))
 line_mesh.clear_surfaces()
 if line_visible:
  var start: Vector3 = rod_tip.global_position
  var sag: float = maxf(0.02, 0.6 * (1.0 - controller.tension)) if state == controller.State.FIGHT else 0.25
  line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
  for index in 17:
   var fraction := float(index) / 16.0
   var point := start.lerp(target, fraction)
   point.y -= sin(fraction * PI) * sag
   line_mesh.surface_add_vertex(to_local(point))
  line_mesh.surface_end()
 update_clock += delta
 if update_clock > 0.1:
  update_clock = 0.0
  _update_fish_visuals()

func _update_fish_visuals() -> void:
 var slot := 0
 var records: Array = ecosystem.fish.duplicate()
 # Spend the fixed visual budget on the fish the player can actually see.
 records.sort_custom(func(a: RefCounted, b: RefCounted) -> bool:
  var here := Vector2(player.global_position.x, player.global_position.z)
  var da := here.distance_squared_to(Vector2(a.position.x, a.position.z))
  var db := here.distance_squared_to(Vector2(b.position.x, b.position.z))
  return da < db if not is_equal_approx(da, db) else a.id < b.id)
 if controller.active_fish != null:
  records.erase(controller.active_fish)
  records.push_front(controller.active_fish)
 for record in records:
  if slot >= visual_pool.size():
   break
  var is_landed: bool = record.state == &"landed"
  if record != controller.active_fish and Vector2(record.position.x - player.global_position.x, record.position.z - player.global_position.z).length() > 55.0:
   continue
  if record.position.y > visible_fish_depth and not is_landed:
   continue
  var visual: Node3D = visual_pool[slot]
  var changed_fish: bool = visual.record != record
  if changed_fish:
   visual.setup(record)
  visual.show()
  if is_landed:
   visual.global_position = player.global_position + Vector3(-2.2, 1.6, -0.5)
   visual.rotation = Vector3(0, time * 0.35, -0.2)
  else:
   visual.global_position = Vector3(record.position.x, water_height - record.position.y, record.position.z)
   var yaw: float = record.heading if changed_fish else lerp_angle(visual.rotation.y, record.heading, 0.4)
   visual.rotation = Vector3(0, yaw, sin(time * 4 + record.id) * 0.035)
  slot += 1
 for index in range(slot, visual_pool.size()):
  visual_pool[index].hide()
