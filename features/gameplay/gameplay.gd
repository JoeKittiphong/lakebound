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
@export var economy_enabled := false
var profile: AnglerProfile
var map_id := "river"
var commerce: CommerceGateway
var _boss_toast := 0.0

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
 camera_rig.bind_touch_controls(hud.move_joystick, hud.rod_joystick)
 pond.definition = $World.definition
 camera_rig.view_changed.connect(_on_view_changed)
 _on_view_changed(camera_rig.global_rotation.y)
 hud.bind(fishing, pond)
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

 if profile != null and not profile.data.pending.is_empty():
  hud.get_node("TacklePanel").open.call_deferred()

func _on_fish_landed(fish: RefCounted) -> void:
 if profile != null:
  fishing.catch_record = {"species": String(fish.species.id), "name": fish.species.display_name,
   "weight": fish.weight, "map": map_id, "depth": fishing.cast_position.y,
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
 player.set_view_yaw(yaw)
 fishing.aim_yaw = yaw

func _on_fishing_state_changed() -> void:
 player.input_enabled = fishing.state != fishing.State.RESULT
 player.set_fighting(fishing.state == fishing.State.FIGHT)
 camera_rig.enabled = fishing.state != fishing.State.RESULT and not _modal_active

func _process(_delta: float) -> void:
 if profile != null:
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
 player.set_rod_pose(fishing.state in [fishing.State.WAITING, fishing.State.BITE, fishing.State.FIGHT, fishing.State.CASTING], fishing.tension, rod.x)

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
 if hud.get_node("TacklePanel").visible:
  hud.get_node("TacklePanel").close()
  return
 if hud.is_collection_open():
  hud.close_collection()
  return
 fishing.cancel()
 get_tree().change_scene_to_file(menu_path)

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
