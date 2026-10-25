extends Node3D
## The saved AnimationPlayer owns the camera and walk path; this bridges character actions.
signal intro_finished
enum Stage { ESTABLISHING, WALKING, CASTING, WAITING }
@export var play_intro: bool = true
@export_range(0.25, 3.0) var playback_speed: float = 1.0
@export_range(0.0, 0.1) var bob_amplitude: float = 0.025
@export_range(0.1, 4.0) var bob_speed: float = 1.3
@onready var timeline: AnimationPlayer = $Timeline
@onready var angler: AnglerModel = $ActorMotion/Angler
@onready var actor_motion: Node3D = $ActorMotion
@onready var bobber: Node3D = $Bobber
@onready var fishing_line: MeshInstance3D = $FishingLine
@onready var ripples: Node3D = $Ripples
@onready var splash: GPUParticles3D = $Splash
@onready var landing: Marker3D = $BobberLanding
var stage: Stage = Stage.ESTABLISHING
var finished := false
var _time := 0.0
var _last_position := Vector3.ZERO
var _line_mesh := ImmediateMesh.new()
var _cast_time := 0.0
var _released := false
var _release_origin := Vector3.ZERO
var _step_distance := 0.0

func _ready() -> void:
 _last_position = actor_motion.position
 fishing_line.mesh = _line_mesh
 angler.aiming = true
 angler.set_fishing_state(FishingController.State.READY, 0.0, 0.0)
 angler.update_motion(0.0, false, 0.0, false)
 timeline.speed_scale = playback_speed
 timeline.play("arrival")
 if not play_intro:
  timeline.advance(0.0)
  timeline.seek(timeline.get_animation("arrival").length, true)
  timeline.pause()
  bobber.show()
  fishing_line.show()
  ripples.show()
  begin_wait()
  angler.update_motion(0.0, false, 0.0, false)
  _last_position = actor_motion.position
  timeline.play("waiting")

func _process(delta: float) -> void:
 _time += delta
 var distance := actor_motion.position.distance_to(_last_position)
 var speed := distance / maxf(delta, 0.0001)
 if stage == Stage.WALKING:
  _step_distance += distance
  if _step_distance >= 0.68:
   _step_distance = fmod(_step_distance, 0.68)
   $Footstep.play()
 _last_position = actor_motion.position
 angler.update_motion(delta, stage == Stage.WALKING, speed, false)
 if stage == Stage.CASTING:
  _cast_time += delta * playback_speed
 if _released and stage == Stage.CASTING:
  var flight := clampf((_cast_time - 0.42) / 0.85, 0.0, 1.0)
  bobber.global_position = _release_origin.lerp(landing.global_position, flight)
  bobber.position.y += sin(flight * PI) * 1.4
 if stage == Stage.WAITING:
  bobber.position.y = landing.position.y + sin(_time * bob_speed) * bob_amplitude
  bobber.rotation.z = sin(_time * 1.6) * 0.055
  for index in ripples.get_child_count():
   var ring := ripples.get_child(index) as Node3D
   var cycle := fmod(_time * 0.32 + index * 0.34, 1.0)
   var radius := 0.35 + cycle * 1.4
   ring.scale = Vector3(radius, 1.0, radius)
 if bobber.visible:
  _update_line()

func _exit_tree() -> void:
 for path in ["WaterAmbience", "Footstep", "CastSound", "SplashSound"]:
  var player := get_node(path) as AudioStreamPlayer
  player.stop()

func begin_walk() -> void:
 stage = Stage.WALKING

func begin_cast() -> void:
 stage = Stage.CASTING
 _cast_time = 0.0
 angler.set_fishing_state(FishingController.State.CASTING, 0.0, 0.0)
 # Release the walk/upper-body blend before asking the AnimationPlayer to cast.
 angler.update_motion(0.0, false, 0.0, false)
 angler.cast(1.45 / playback_speed)
 $CastSound.play()

func release_line() -> void:
 _release_origin = angler.rod_tip_position()
 _released = true
 bobber.global_position = _release_origin
 bobber.show()
 fishing_line.show()

func land_bobber() -> void:
 bobber.global_position = landing.global_position
 ripples.show()
 splash.emitting = true
 $SplashSound.play()

func begin_wait() -> void:
 stage = Stage.WAITING
 bobber.global_position = landing.global_position
 angler.set_fishing_state(FishingController.State.WAITING, 0.0, 0.0)
 finished = true
 intro_finished.emit()

func _on_animation_finished(animation_name: StringName) -> void:
 if animation_name == &"arrival":
  timeline.play("waiting")

func _update_line() -> void:
 # Only the moving fishing line is procedural; all scenery is authored in the scene.
 _line_mesh.clear_surfaces()
 _line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
 var tip := fishing_line.to_local(angler.rod_tip_position())
 var end := fishing_line.to_local(bobber.global_position)
 for index in 17:
  var fraction := float(index) / 16.0
  var point := tip.lerp(end, fraction)
  point.y -= sin(fraction * PI) * 0.13
  _line_mesh.surface_add_vertex(point)
 _line_mesh.surface_end()
