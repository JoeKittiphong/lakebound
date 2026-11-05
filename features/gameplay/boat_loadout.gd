extends RefCounted
## Session-owned boat: purchased inventory persists, deployed hulls do not.
var game: Node
var placing := false
var active_item: TackleItem
var candidate := Vector3.INF
var candidate_yaw := 0.0
var placement_error := ""

func setup(value: Node) -> void:
 game = value
 if is_instance_valid(game.vessel): game.vessel.set_deployed(false)
 game.hud.boat_use_requested.connect(use)
 game.hud.boat_pack_requested.connect(pack)
 game.hud.boat_place_requested.connect(confirm)
 game.hud.boat_place_cancelled.connect(cancel)

func on_shore() -> bool:
 var player: AnglerPlayer = game.player
 var definition := player.pond.definition
 return player.boat == null and not player.swimming and player.is_on_floor() and not definition.can_swim_at(player.global_position) and not definition.is_wading(player.global_position)

func _message(value: String) -> void:
 game.fishing.feedback = value
 game.hud._show_toast(value)

func use() -> void:
 if game.profile == null or game.hud.competition_mode: return
 if placing: cancel(); return
 if game.vessel != null and game.vessel.deployed:
  _message("เก็บเรือเดิมก่อนเรียกใช้ใหม่"); return
 var item: TackleItem = game.profile.equipped("boat")
 if item == null or game.profile.quantity(str(item.id)) < 1:
  var owned := TackleCatalog.ITEMS.any(func(entry:Resource):return entry.kind=="boat" and game.profile.quantity(str(entry.id))>0)
  if owned: game.hud.get_node("TacklePanel").open_category(6)
  else: _message("ยังไม่มีเรือ · ซื้อจากหมวดเรือที่ร้านหน้าเมนู")
  return
 if not on_shore():
  _message("เรียกใช้เรือได้เมื่อยืนบนฝั่งเท่านั้น"); return
 if game._modal_active or game.fishing.state not in [FishingController.State.READY,FishingController.State.LOST]: return
 if game.fishing.state == FishingController.State.LOST: game.fishing.reset_cast()
 if not _prepare_hull(item): return
 placing = true
 game.player.run_requested = false
 game.player.input_enabled = false
 game.hud.move_joystick.enabled = false
 game.hud.rod_joystick.enabled = false
 game.hud.get_node("BoatPlacement").show()
 game.camera_rig.set_fishing_view(false)
 update()

func _prepare_hull(item: TackleItem) -> bool:
 if item.boat_spec == null or not ResourceLoader.exists(item.boat_spec.scene_path):
  _message("ยังไม่พบฉากของเรือรุ่นนี้"); return false
 if active_item != item:
  var old: FishingBoat = game.vessel
  var packed := load(item.boat_spec.scene_path) as PackedScene
  if packed == null: return false
  var created := packed.instantiate()
  if not created is FishingBoat:
   created.free(); _message("ฉากเรือรุ่นนี้ยังไม่รองรับการใช้งาน"); return false
  var hull := created as FishingBoat
  if is_instance_valid(old):
   old.get_parent().remove_child(old); old.queue_free()
  hull.name = "FishingBoat"
  hull.pond = game.player.pond
  game.add_child(hull)
  game.vessel = hull
  hull.apply_spec(item.boat_spec)
  hull.set_deployed(false)
  active_item = item
 return true

func placement_reason(point: Vector3, yaw: float) -> String:
 if not point.is_finite() or active_item == null: return "แพนกล้องเล็งจุดในน้ำ"
 var player: AnglerPlayer = game.player
 var definition := player.pond.definition
 if not on_shore(): return "ต้องยืนบนฝั่งเพื่อวางเรือ"
 var distance := Vector2(point.x-player.position.x,point.z-player.position.z).length()
 if distance < 3.0 or distance > active_item.boat_spec.placement_distance: return "เลือกน้ำห่างฝั่ง 3–%.0f เมตร" % active_item.boat_spec.placement_distance
 if definition.constrain_travel(point).distance_to(point) > .05: return "จุดนี้อยู่นอกพื้นที่เล่น"
 # Derive the footprint from the actual hull, including future larger models.
 var shape: CollisionShape3D = game.vessel.get_node("CollisionShape3D")
 var half_size := shape.shape.get_debug_mesh().get_aabb().size * .5 + Vector3(.1,0,.1)
 for x in [-half_size.x,0.0,half_size.x]:
  for z in [-half_size.z,0.0,half_size.z]:
   var sample: Vector3 = point + (shape.position + Vector3(x,0,z)).rotated(Vector3.UP,yaw)
   if definition.constrain_travel(sample).distance_to(sample) > .05: return "ตัวเรืออยู่นอกพื้นที่เล่น"
   if definition.water_depth_at(Vector2(sample.x,sample.z)) < game.vessel.minimum_depth: return "น้ำตื้นหรือชิดฝั่งเกินไป"
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = shape.shape
 query.transform = Transform3D(Basis(Vector3.UP,yaw),point) * shape.transform
 query.exclude = [game.vessel.get_rid(),player.get_rid()]
 query.collision_mask = 1
 if not player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return "มีสิ่งกีดขวางตรงจุดวางเรือ"
 # Prevent placing through a wall or under an inaccessible roof from afar.
 var ray := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP,point+Vector3.UP*.3)
 ray.exclude = query.exclude
 if not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return "มีสิ่งกีดขวางระหว่างคุณกับจุดวาง"
 return ""

func update() -> void:
 if not placing: return
 if game._modal_active or game.player.swimming:
  cancel(); return
 var camera: Camera3D = game.camera_rig.get_node("Camera3D")
 var screen: Vector2 = game.hud.get_node("BoatPlacement/Reticle").get_global_rect().get_center()
 var origin := camera.project_ray_origin(screen)
 var direction := camera.project_ray_normal(screen)
 var height: float = game.player.pond.definition.surface_height()
 candidate = Vector3.INF
 if direction.y < -.001:
  var distance := (height-origin.y)/direction.y
  if distance > 0: candidate = origin + direction * distance
 candidate_yaw = game.camera_rig.rotation.y
 placement_error = placement_reason(candidate,candidate_yaw)
 var hull: FishingBoat = game.vessel
 hull.visible = candidate.is_finite()
 if candidate.is_finite():
  hull.position = candidate; hull.rotation.y = candidate_yaw
 _ghost(true)
 var hint: Label = game.hud.get_node("BoatPlacement/Panel/Content/Hint")
 hint.text = "จุดนี้วางได้ · แพนกล้องเพื่อย้ายจุด แล้วกดวางเรือ" if placement_error.is_empty() else placement_error
 hint.modulate = Color(.6,1,.75) if placement_error.is_empty() else Color(1,.75,.5)
 game.hud.get_node("BoatPlacement/Panel/Content/Buttons/Confirm").disabled = not placement_error.is_empty()

func _ghost(active: bool) -> void:
 for mesh in game.vessel.find_children("*","GeometryInstance3D",true,false): mesh.transparency = .5 if active else 0.0

func confirm() -> void:
 if not placing: return
 if game.profile.equipped("boat") != active_item or game.profile.quantity(str(active_item.id)) < 1:
  cancel(); _message("เลือกเรือที่เป็นเจ้าของก่อนวาง"); return
 var reason := placement_reason(candidate,candidate_yaw)
 if not reason.is_empty(): _message(reason); return
 game.vessel.position = candidate
 game.vessel.rotation.y = candidate_yaw
 _ghost(false)
 game.vessel.set_deployed(true)
 game.profile.boat_in_use = true
 _finish_placement()
 _message("วางเรือแล้ว · เข้าใกล้เพื่อขึ้นเรือ")

func _finish_placement() -> void:
 placing = false
 game.hud.get_node("BoatPlacement").hide()
 game.player.input_enabled = not game._modal_active
 game.hud.move_joystick.enabled = true
 game.hud.rod_joystick.enabled = true

func cancel() -> void:
 if not placing: return
 _ghost(false)
 game.vessel.set_deployed(false)
 _finish_placement()

func pack() -> void:
 if game.profile == null or game.vessel == null or not game.vessel.deployed: return
 if game._modal_active or game.fishing.state == FishingController.State.RESULT: return
 if game.player.boat_driving(): _message("เลิกขับก่อนเก็บเรือ"); return
 if game.player.boat == null and game.player.position.distance_to(game.vessel.position) > game.vessel.boarding_distance:
  _message("กลับเข้าใกล้เรือก่อนเก็บ"); return
 game.fishing.cancel()
 if game.player.boat != null and not game.vessel.disembark():
  _message("ไม่มีพื้นที่ปลอดภัยให้ลงก่อนเก็บเรือ"); return
 game.vessel.set_deployed(false)
 game.profile.boat_in_use = false
 _message("เก็บเรือกลับช่องอุปกรณ์แล้ว")
