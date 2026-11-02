extends Node3D
## One authored Timeline owns the camera, travel, skeleton and action cues.
signal intro_finished
enum Stage { ESTABLISHING, WALKING, SETTLING, CASTING, WAITING }
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
var _line_mesh := ImmediateMesh.new()
var _released := false
var _release_pending := false
var _landed := false
var _release_origin := Vector3.ZERO
var _release_time := 0.0
var _landing_time := 0.0
@onready var _boat_origin: Vector3 = $Scenery/BoatFloat.position

func _ready() -> void:
 fishing_line.mesh = _line_mesh
 # The cinematic has a full-body performance; gameplay's locomotion/reel layers
 # must not overwrite it. The original imported clips remain shared and unchanged.
 angler.animation_player.stop()
 angler.animation_player.active = false
 angler.locomotion_tree.active = false
 angler.rod_mesh.show()
 var arrival := timeline.get_animation("arrival")
 for track in arrival.get_track_count():
  if arrival.track_get_type(track) != Animation.TYPE_METHOD:
   continue
  for key in arrival.track_get_key_count(track):
   var cue: Dictionary = arrival.track_get_key_value(track, key)
   if cue.method == &"release_line":
    _release_time = arrival.track_get_key_time(track, key)
   elif cue.method == &"land_bobber":
    _landing_time = arrival.track_get_key_time(track, key)
 timeline.speed_scale = playback_speed
 timeline.play("arrival")
 # Apply the authored resting pose before the very first visible loading frame.
 timeline.advance(0.0)
 if not play_intro:
  timeline.seek(timeline.get_animation("arrival").length, true)
  timeline.pause()
  bobber.show()
  fishing_line.show()
  ripples.show()
  begin_wait()
  timeline.play("waiting")
  timeline.advance(0.0)

func _process(delta: float) -> void:
 _time += delta * playback_speed
 $Scenery/BoatFloat.position.y = _boat_origin.y + sin(_time * 1.15) * 0.025
 $Scenery/BoatFloat.rotation.z = sin(_time * 0.85) * 0.012
 $Scenery/BoatFloat.rotation.x = cos(_time * 0.7) * 0.008
 if _release_pending:
  _release_pending = false
  _release_origin = _rod_tip_position()
  _released = true
  bobber.global_position = landing.global_position if _landed else _release_origin
  bobber.show()
  fishing_line.show()
  $CastSound.play()
 if _released and not _landed:
  var flight := clampf((timeline.current_animation_position - _release_time) / maxf(_landing_time - _release_time, 0.01), 0.0, 1.0)
  bobber.global_position = _release_origin.lerp(landing.global_position, flight)
  # A ballistic arc with a finite downward velocity at water contact.
  bobber.global_position.y += 4.0 * flight * (1.0 - flight) * 0.85
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
 angler.current_action = &"Walk"

func finish_walk() -> void:
 stage = Stage.SETTLING

func footstep() -> void:
 if stage == Stage.WALKING:
  $Footstep.play()

func begin_cast() -> void:
 stage = Stage.CASTING
 angler.current_action = &"Fishing_Cast"

func release_line() -> void:
 # Capture after the Timeline has applied this frame's full skeleton pose.
 _release_pending = true

func land_bobber() -> void:
 _landed = true
 bobber.global_position = landing.global_position
 ripples.show()
 splash.emitting = true
 $SplashSound.play()

func begin_wait() -> void:
 # Deferred animation cues may arrive after a scene change removed the intro.
 if not is_inside_tree():
  return
 stage = Stage.WAITING
 bobber.global_position = landing.global_position
 angler.current_action = &"Fishing_Reel"
 if not finished:
  finished = true
  intro_finished.emit()

func _on_animation_finished(animation_name: StringName) -> void:
 if animation_name == &"arrival":
  timeline.play("waiting")

func _update_line() -> void:
 # Only the moving fishing line is procedural; all scenery is authored in the scene.
 _line_mesh.clear_surfaces()
 _line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
 var tip := fishing_line.to_local(_rod_tip_position())
 var end := fishing_line.to_local(bobber.global_position)
 for index in 17:
  var fraction := float(index) / 16.0
  var point := tip.lerp(end, fraction)
  point.y -= sin(fraction * PI) * 0.13
  _line_mesh.surface_add_vertex(point)
 _line_mesh.surface_end()

func _rod_tip_position() -> Vector3:
 # BoneAttachment updates can lag the AnimationMixer's method cue. Evaluate the
 # existing grip and flexible rod against the current hand pose on the same clock.
 angler.skeleton.force_update_all_bone_transforms()
 var hand := angler.skeleton.find_bone("hand_r")
 var hand_world := angler.skeleton.global_transform * angler.skeleton.get_bone_global_pose(hand)
 var tip_local := angler.rod_mesh.to_local(angler.rod_tip_position())
 return hand_world * angler.rod_grip.transform * angler.rod_mesh.transform * tip_local
