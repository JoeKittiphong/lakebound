extends Node3D

@onready var collection: Node = get_node("/root/FishCollection")
@export_file("*.tscn") var menu_path: String = "res://features/menu/main_menu.tscn"
@onready var player: AnglerPlayer = $Player
@onready var camera_rig: AnglerCameraRig = $CameraRig
@onready var fishing: FishingController = $FishingController
@onready var pond: PondEcosystem = $PondEcosystem
@onready var hud: FishingHUD = $HUD/FishingHUD
var _modal_active := false
var _previous_pause := false

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(camera_rig):
  camera_rig.reset_input()
 elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
  _on_back_pressed()
 elif what == NOTIFICATION_WM_CLOSE_REQUEST:
  get_tree().quit()

func _ready() -> void:
 player.input_enabled = true
 player.facing_follows_camera = true
 player.joystick = hud.move_joystick
 pond.definition = $World.definition
 camera_rig.view_changed.connect(_on_view_changed)
 hud.bind(fishing, pond)
 hud.action_requested.connect(_on_action)
 hud.cancel_requested.connect(fishing.cancel)
 hud.keep_requested.connect(func(): fishing.resolve_catch(true))
 hud.release_requested.connect(func(): fishing.resolve_catch(false))
 hud.aim_released.connect(_on_aim_released)
 hud.configuration_changed.connect(_on_configuration_changed)
 hud.back_requested.connect(_on_back_pressed)
 hud.collection_visibility_changed.connect(_on_collection_visibility_changed)
 fishing.cast_started.connect(player.play_cast)
 fishing.fish_landed.connect(_on_fish_landed)
 fishing.state_changed.connect(_on_fishing_state_changed)
 _on_fishing_state_changed()

func _on_fish_landed(fish: RefCounted) -> void:
 collection.record_catch_result(fish)
 hud.show_catch_result(fish, collection.save_error)

func _on_view_changed(yaw: float) -> void:
 player.set_view_yaw(yaw)
 fishing.aim_yaw = yaw

func _on_fishing_state_changed() -> void:
 player.input_enabled = fishing.state != fishing.State.RESULT
 player.set_fighting(fishing.state == fishing.State.FIGHT)
 camera_rig.enabled = fishing.state != fishing.State.RESULT and not _modal_active

func _process(_delta: float) -> void:
 var rod := hud.rod_direction()
 var keys := Input.get_vector("rod_left", "rod_right", "reel_out", "reel_in")
 if keys.length() > rod.length():
  rod = keys
 fishing.rod_input = rod
 if fishing.state == fishing.State.READY:
  fishing.set_aim(rod)
 _on_view_changed(camera_rig.rotation.y)
 player.set_rod_pose(fishing.state in [fishing.State.WAITING, fishing.State.BITE, fishing.State.FIGHT, fishing.State.CASTING], fishing.tension, rod.x)

func _unhandled_input(event: InputEvent) -> void:
 if event.is_action_pressed("fish_action"):
  _on_action()
  get_viewport().set_input_as_handled()
 elif event.is_action_pressed("cancel_cast"):
  fishing.cancel()
  get_viewport().set_input_as_handled()

func _on_action() -> void:
 if fishing.state == fishing.State.READY:
  fishing.cast()
 elif fishing.state == fishing.State.BITE:
  fishing.strike()

func _on_aim_released() -> void:
 if fishing.state == fishing.State.READY:
  fishing.cast()

func _on_configuration_changed(bait: StringName, depth: float) -> void:
 if fishing.state == fishing.State.READY:
  fishing.selected_bait = bait
  fishing.selected_depth = depth

func _on_collection_visibility_changed(opened: bool) -> void:
 camera_rig.reset_input()
 if opened and not _modal_active:
  _previous_pause = get_tree().paused
  _modal_active = true
  get_tree().paused = true
 elif not opened and _modal_active:
  get_tree().paused = _previous_pause
  _modal_active = false
 _on_fishing_state_changed()

func _exit_tree() -> void:
 if _modal_active:
  get_tree().paused = _previous_pause

func _on_back_pressed() -> void:
 if hud.is_collection_open():
  hud.close_collection()
  return
 fishing.cancel()
 get_tree().change_scene_to_file(menu_path)
