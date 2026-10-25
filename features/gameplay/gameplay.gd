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
var _mission_region_ready := false
@export var economy_enabled := false
var profile: AnglerProfile
@export var map_id := "river"
@export var maximum_fishing_depth: float = 5.5
var commerce: CommerceGateway
var _boss_toast := 0.0
@onready var vessel: FishingBoat = get_node_or_null("FishingBoat")

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(camera_rig):
  camera_rig.reset_input()
  if is_instance_valid(fishing):
   fishing.lure_input.reset()
   fishing.lure_holding = false
 elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
  _on_back_pressed()
 elif what == NOTIFICATION_WM_CLOSE_REQUEST:
  get_tree().quit()

func _ready() -> void:
 hud.get_node("SafeArea/BaitPanel/Content/DepthRow/Depth").max_value = maximum_fishing_depth
 fishing.map_id = map_id
 hud.get_node("TacklePanel").map_id = map_id
 hud.get_node("MissionPanel").map_id = map_id
 if economy_enabled:
  profile = get_node("/root/AnglerSave")
  fishing.bind_profile(profile)
  if profile.data.ponds.has(map_id):
   if not pond.restore(profile.data.ponds[map_id]):
    profile.incompatible = true
    profile.save_error = "ข้อมูลบ่อเดิมไม่ถูกต้อง — เก็บไฟล์ไว้และหยุดการเขียนทับ"
  else:
   pond.reset_population(randi())
   profile.store_pond(map_id, pond.snapshot())
  commerce = $CommerceGateway
  hud.get_node("TacklePanel").bind(profile, fishing, pond, commerce)
  hud.get_node("TacklePanel").opened.connect(func(): _on_collection_visibility_changed(true))
  hud.get_node("TacklePanel").closed.connect(func(): _on_collection_visibility_changed(false))
  commerce.reward_completed.connect(func(receipt: String, recovery_id: String): profile.apply_verified_reward(receipt, recovery_id))
  commerce.purchase_completed.connect(func(receipt: String, diamonds: int): profile.apply_verified_purchase(receipt, diamonds))
  profile.changed.connect(_refresh_profile)
  profile.missions_completed.connect(hud.notify_missions_completed)
  pond.population_changed.connect(_refresh_profile)
  collection.changed.connect(_refresh_profile)
  fishing.fish_lost.connect(func(_reason: String):
   profile.store_pond(map_id, pond.snapshot())
   if not profile.data.pending.is_empty():
    hud.get_node("TacklePanel").open())
  _refresh_profile()
  _boss_toast = 5.0
 player.input_enabled = true
 player.facing_follows_camera = true
 player.joystick = hud.move_joystick
 hud.jump_requested.connect(player.request_jump)
 hud.greet_requested.connect(player.request_greeting)
 hud.run_toggled.connect(func(enabled: bool): player.run_requested = enabled)
 player.swimming_changed.connect(_on_swimming_changed)
 hud.boat_action_requested.connect(_on_boat_action)
 hud.boat_exit_requested.connect(_on_boat_exit)
 camera_rig.bind_touch_controls(hud.move_joystick, hud.rod_joystick)
 pond.definition = $World.definition
 camera_rig.view_changed.connect(_on_view_changed)
 _on_view_changed(camera_rig.global_rotation.y)
 hud.bind(fishing, pond)
 hud.orbit_requested.connect(camera_rig.set_orbiting)
 hud.orbit_dragged.connect(camera_rig.drag_orbit)
 if profile != null:
  hud.get_node("MissionPanel").bind(profile)
  hud.get_node("MissionPanel").opened.connect(func(): _on_collection_visibility_changed(true))
  hud.get_node("MissionPanel").closed.connect(func(): _on_collection_visibility_changed(false))
  _start_missions_if_ready()
 hud.keep_requested.connect(func(): fishing.resolve_catch(true))
 hud.release_requested.connect(func(): fishing.resolve_catch(false))
 hud.aim_released.connect(_on_aim_released)
 hud.configuration_changed.connect(_on_configuration_changed)
 hud.back_requested.connect(_on_back_pressed)
 hud.collection_visibility_changed.connect(_on_collection_visibility_changed)
 fishing.cast_started.connect(func(): player.play_cast(fishing.tuning.cast_duration))
 fishing.fish_landed.connect(_on_fish_landed)
 fishing.state_changed.connect(_on_fishing_state_changed)
 _on_fishing_state_changed()

 if profile != null and not profile.data.pending.is_empty():
  hud.get_node("TacklePanel").open.call_deferred()

func _on_fish_landed(fish: RefCounted) -> void:
 if profile != null:
  if fishing.catch_event_id.is_empty():
   fishing.catch_event_id = Crypto.new().generate_random_bytes(16).hex_encode()
  fishing.catch_record = {"species": String(fish.species.id), "name": fish.species.display_name,
   "weight": fish.weight, "map": map_id, "depth": fishing.bite_depth,
   "catch_id": fishing.catch_event_id, "fish_key": map_id + ":" + fish.persistent_key,
   "bait_id": fishing.cast_bait_id if not fishing.cast_bait_id.is_empty() else String(profile.equipped("bait").id),
   "bait_kind": profile.equipped("bait").kind, "boss": pond.boss() == fish,
   "mission_eligible": bool(profile.data.missions.started) and not hud.get_node("SafeArea/FirstCatch").active,
   "bait": profile.equipped("bait").display_name, "rod": profile.equipped("rod").display_name,
   "reel": profile.equipped("reel").display_name, "line": profile.equipped("line").display_name,
   "time": Time.get_unix_time_from_system()}
  profile.record_catch(fishing.catch_record, pond.boss() == fish)
 var outcome: Dictionary = collection.record_catch_result(fish)
 if profile != null:
  fishing.feedback = collection.catch_message(outcome) + " • เก็บในกล่องหรือปล่อยกลับ"
  if not profile.save_error.is_empty():
   fishing.feedback = profile.save_error
 hud.show_catch_result(fish, collection.save_error)

func _on_view_changed(yaw: float) -> void:
 if camera_rig.orbiting:
  return
 # Traversal follows the stick; aiming follows the cast direction.
 if not player.swimming and (hud.is_aiming() or player.fishing_active or player.boat_fishing()):
  player.set_view_yaw(yaw)
 fishing.aim_yaw = yaw

func _on_fishing_state_changed() -> void:
 player.input_enabled = fishing.state != fishing.State.RESULT
 player.set_fighting(fishing.state == fishing.State.FIGHT)
 player.set_fishing_animation_state(fishing.state, maxf(0.0, fishing.rod_input.y), fishing.tension)
 camera_rig.enabled = fishing.state != fishing.State.RESULT and not _modal_active

func _process(_delta: float) -> void:
 hud.set_traversal_state(player.swimming, player.can_fish(), player.input_enabled)
 if vessel != null:
  hud.set_boat_state(vessel.can_board(player), player.boat != null, player.boat_driving(), vessel.exit_point.is_finite(), player.input_enabled and fishing.state != FishingController.State.RESULT, not player.boat_driving() or vessel.can_stand_to_fish())
 if profile != null:
  _start_missions_if_ready()
  _boss_toast = maxf(0.0, _boss_toast - _delta)
  hud.get_node("SafeArea/BossToast").visible = _boss_toast > 0 and fishing.state == fishing.State.READY
  if Input.is_physical_key_pressed(KEY_E) and fishing.state == fishing.State.WAITING and fishing.using_lure():
   fishing.lure_input.press()
  elif fishing.lure_input.pressed and not hud.get_node("SafeArea/LureAction").button_pressed:
   fishing.lure_input.release()
 var rod := hud.rod_direction()
 var keys := Input.get_vector("rod_left", "rod_right", "reel_out", "reel_in")
 if keys.length() > rod.length():
  rod = keys
 fishing.rod_input = rod
 if fishing.state == fishing.State.READY:
  fishing.set_aim(rod)
 _on_view_changed(camera_rig.rotation.y)
 var aiming := hud.is_aiming() or player.boat_fishing()
 player.set_aiming(aiming)
 player.set_rod_pose(aiming or fishing.state in [fishing.State.WAITING, fishing.State.BITE, fishing.State.FIGHT, fishing.State.CASTING], fishing.tension, rod.x)
 player.set_fishing_animation_state(fishing.state, maxf(0.0, fishing.rod_input.y), fishing.tension)

func _on_boat_action() -> void:
 if vessel == null or _modal_active or fishing.state == FishingController.State.RESULT:
  return
 if player.boat == null:
  vessel.board(player)
 elif player.boat_driving():
  vessel.start_fishing()
 else:
  fishing.cancel()
  vessel.start_driving()
  player.set_rod_pose(false, 0.0, 0.0)

func _on_boat_exit() -> void:
 if vessel == null or player.boat == null or _modal_active or fishing.state == FishingController.State.RESULT:
  return
 if vessel.find_shore_exit().is_finite():
  fishing.cancel()
  vessel.disembark()


func _on_swimming_changed(active: bool) -> void:
 if active and fishing.state not in [FishingController.State.READY, FishingController.State.RESULT]:
  fishing.cancel()
 if active:
  player.set_rod_pose(false, 0.0, 0.0)

func _unhandled_input(event: InputEvent) -> void:
 if event.is_action_pressed("cancel_cast"):
  fishing.cancel()
  get_viewport().set_input_as_handled()

func _on_aim_released() -> void:
 if fishing.state == fishing.State.READY:
  fishing.cast()

func _on_configuration_changed(bait: StringName, depth: float) -> void:
 if fishing.state == fishing.State.READY:
  if profile == null:
   fishing.selected_bait = bait
  fishing.selected_depth = depth

func _on_collection_visibility_changed(opened: bool) -> void:
 camera_rig.reset_input()
 if opened:
  hud.get_node("SafeArea/FirstCatch").hide()
 if opened and not _modal_active:
  _previous_pause = get_tree().paused
  _modal_active = true
  get_tree().paused = true
 elif not opened and _modal_active:
  get_tree().paused = _previous_pause
  _modal_active = false
 _on_fishing_state_changed()

func _exit_tree() -> void:
 if profile != null and is_instance_valid(pond):
  profile.store_pond(map_id, pond.snapshot())
 if _modal_active:
  get_tree().paused = _previous_pause

func _on_back_pressed() -> void:
 if hud.get_node("MissionPanel").visible:
  hud.get_node("MissionPanel").close()
  return
 if hud.get_node("TacklePanel").visible:
  hud.get_node("TacklePanel").close()
  return
 if hud.is_collection_open():
  hud.close_collection()
  return
 fishing.cancel()
 if fishing.state == FishingController.State.RESULT:
  return
 get_tree().change_scene_to_file(menu_path)

func _start_missions_if_ready() -> void:
 _track_current_region()
 if profile != null and not profile.data.missions.started and not hud.get_node("SafeArea/FirstCatch").active:
  # Avoid retrying an unavailable save every frame. The mission panel provides
  # an explicit retry, while free fishing remains available.
  if profile.save_error.is_empty() and not profile.incompatible:
   profile.start_missions()

func _track_current_region() -> void:
 if profile == null or not profile.data.missions.started or _mission_region_ready:return
 _mission_region_ready = true
 var tracked := MissionCatalog.find(profile.data.missions.tracked)
 if tracked != null and tracked.map_id == map_id:return
 for definition in MissionCatalog.ALL_ITEMS:
  if definition.map_id == map_id and not MissionProgress.completed(profile.data.missions, definition):
   profile.track_mission(definition.id)
   break

func _refresh_profile() -> void:
 if profile == null:
  return
 fishing.refresh_equipment()
 hud.sync_equipment()
 hud.get_node("SafeArea/TackleButton").visible = true
 hud.get_node("SafeArea/TackleButton").text = "กระเป๋า · %d เหรียญ" % profile.data.coins
 var boss := pond.boss()
 if boss != null:
  var discovered: bool = collection.stats(boss.species.id).count > 0
  hud.get_node("SafeArea/BossToast").text = "จ้าวบ่อ: %s — %.2f กก." % [boss.species.display_name if discovered else "???", boss.weight]
