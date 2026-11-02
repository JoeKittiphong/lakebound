extends Node3D

const FishVisual = preload("res://world/pond/fish_visual.tscn")
@export var controller: FishingController
@export var player: Node3D
@export var ecosystem: PondEcosystem
@export var rod_tip: Node3D
@export var water_interactions: Node3D
@export var audio_enabled := true
@export_range(1,24) var maximum_visible_fish:=7
@export_range(1.0, 8.0) var visible_fish_depth: float = 5.0
@export var water_height: float = -0.18
@onready var line_mesh: ImmediateMesh = $Line.mesh
var visual_pool: Array[Node3D] = []
var _visible_candidates: Array = []
var update_clock := 0.0
var time := 0.0

func _ready() -> void:
 for index in maximum_visible_fish:
  var visual := FishVisual.instantiate() as Node3D
  $FishVisuals.add_child(visual)
  visual.hide()
  visual_pool.append(visual)
 controller.bite_notified.connect(_on_bite)
 controller.fish_landed.connect(_on_landed)

func _on_bite() -> void:
 if controller.using_lure() and controller.active_fish != null:
  $SurfaceSpray.water_height = water_height
  $SurfaceSpray.observer = player.global_position
  $SurfaceSpray.water_interactions = water_interactions
  $SurfaceSpray.strike(controller.active_fish.position, controller.active_fish.weight)
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
 if state == controller.State.WAITING and controller.using_lure():
  working_reel = audio_enabled and (controller.rod_input.y > 0.15 or controller.lure_holding)
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
 if controller.profile != null:
  var terminal := controller.active_terminal_rig()
  if terminal != null and terminal.technique not in ["cast_float", "pole_float"]: $Bobber.hide()
 $BaitInterest.present(ecosystem.bait_interest_status(),controller.cast_position,water_height)
 if state not in [controller.State.WAITING,controller.State.BITE]:$BaitInterest.hide()
 var target: Vector3 = controller.get_aim_position()
 target.y = -0.13
 if not ready_state:
  target = Vector3(controller.cast_position.x, -0.12, controller.cast_position.z)
 if state == controller.State.FIGHT and controller.active_fish != null:
  target = Vector3(controller.active_fish.position.x, -0.12, controller.active_fish.position.z)
 var lure: bool = controller.using_lure()
 var submerged := lure
 if controller.profile != null and controller.active_terminal_rig() != null:
  submerged = submerged or controller.active_terminal_rig().technique in ["cast_bottom", "boat_drop", "vertical_jig"]
 $SurfaceSpray.water_height = water_height
 $SurfaceSpray.water_interactions = water_interactions
 $SurfaceSpray.advance(delta, controller.cast_position, lure and state == controller.State.WAITING, ecosystem.fish, player.global_position)
 $LureVisual.visible = state in [controller.State.WAITING, controller.State.BITE, controller.State.CASTING,controller.State.FIGHT]
 if submerged and line_visible:
  if lure: $Bobber.hide()
  target.y = water_height - controller.cast_position.y
 if controller.profile != null and state == controller.State.FIGHT and controller.active_fish != null:
  target.y = water_height - controller.active_fish.position.y
 if state == controller.State.CASTING:
  var fraction: float = controller.cast_progress()
  target = (player.global_position + Vector3(0.4, 1.7, 0)).lerp(target, fraction)
  if not controller.is_drop_method(): target.y += sin(fraction * PI) * 2.5
 $AimMarker.global_position = Vector3(target.x, -0.12, target.z)
 $Bobber.global_position = target + Vector3(0, sin(time * 3.0) * 0.045, 0)
 if $LureVisual.visible:
  var entry:TackleItem=controller.active_bait_item() if controller.active_bait_item()!=null else TackleCatalog.item("worm")
  $LureVisual.set_item(entry)
  var bait_world:=Vector3(controller.cast_position.x,water_height-controller.cast_position.y,controller.cast_position.z)
  if state in [controller.State.CASTING,controller.State.FIGHT]:bait_world=target
  $LureVisual.global_position=bait_world
  var heading:=player.global_position-bait_world
  $LureVisual.rotation.y=atan2(heading.z,-heading.x)
  $LureVisual.rotation.z=sin(time*10)*.15 if lure and controller.lure_holding else 0.0
 else:$LureVisual.release_model()
 if state == controller.State.BITE:
  $Bobber.global_position.y -= absf(sin(time * 15.0)) * 0.35
 $Line.hide()
 $TexturedLine.visible = line_visible
 $BaitLeader.visible=$Bobber.visible and $LureVisual.visible and state!=controller.State.CASTING
 line_mesh.clear_surfaces()
 if line_visible:
  var start: Vector3 = rod_tip.global_position
  var sag: float = maxf(0.02, 0.6 * (1.0 - controller.tension)) if state == controller.State.FIGHT else 0.25
  var ribbon_points := PackedVector3Array()
  line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
  for index in 17:
   var fraction := float(index) / 16.0
   var point := start.lerp(target, fraction)
   point.y -= sin(fraction * PI) * sag
   line_mesh.surface_add_vertex(to_local(point))
   ribbon_points.append(point)
  line_mesh.surface_end()
  $TexturedLineStart.global_position = start
  $TexturedLineEnd.global_position = target
  var camera := get_viewport().get_camera_3d()
  if camera != null:
   $TexturedLine.camera_path = $TexturedLine.get_path_to(camera)
   $TexturedLine.control_points = ribbon_points
   var style: String = controller.profile.equipped("line").line_visual_style if controller.profile != null and controller.profile.equipped("line") != null else "mono"
   if player is AnglerPlayer:
    var visible_rod = player.first_person_rod if is_instance_valid(player.first_person_rod) else player.character_model.rod_mesh
    if visible_rod is DetailedFishingRod: style = visible_rod.line_style
   var color: Color = {"mono": Color(0.44,0.67,0.78), "fluoro": Color(0.69,0.74,0.68), "braid": Color(0.47,0.58,0.27), "fly": Color(0.91,0.38,0.15)}[style]
   ($TexturedLine.material_override as ShaderMaterial).set_shader_parameter("line_color", color)
   $TexturedLine.width = 0.001 if style == "fly" else 0.0007
   $TexturedLine.refresh()
   if $BaitLeader.visible:
    $BaitLeaderStart.global_position=$Bobber.global_position
    $BaitLeaderEnd.global_position=$LureVisual.get_node("LineTie").global_position
    $BaitLeader.camera_path=$BaitLeader.get_path_to(camera)
    $BaitLeader.width=$TexturedLine.width
    $BaitLeader.refresh()

 update_clock += delta
 if update_clock > 0.1:
  update_clock = 0.0
  _update_fish_visuals()

func _update_fish_visuals() -> void:
 var slot := 0
 var here := Vector2(player.global_position.x, player.global_position.z)
 _visible_candidates.clear()
 # Reject invisible fish before sorting; retain the configured visual budget,
 # depth rules and deterministic nearest-first ordering.
 for record in ecosystem.fish:
  if record == controller.active_fish:
   continue
  if record.position.y > visible_fish_depth and record.state != &"landed":
   continue
  if here.distance_squared_to(Vector2(record.position.x, record.position.z)) <= 55.0 * 55.0:
   _visible_candidates.append(record)
 _visible_candidates.sort_custom(func(a: RefCounted, b: RefCounted) -> bool:
  if (a.state in [&"chasing_lure",&"committed"]) != (b.state in [&"chasing_lure",&"committed"]):
   return a.state in [&"chasing_lure",&"committed"]
  var da := here.distance_squared_to(Vector2(a.position.x, a.position.z))
  var db := here.distance_squared_to(Vector2(b.position.x, b.position.z))
  return da < db if not is_equal_approx(da, db) else a.id < b.id)
 var active := controller.active_fish
 if active != null and (active.position.y <= visible_fish_depth or active.state == &"landed"):
  _visible_candidates.push_front(active)
 for record in _visible_candidates:
  if slot >= visual_pool.size():
   break
  var is_landed: bool = record.state == &"landed"
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
