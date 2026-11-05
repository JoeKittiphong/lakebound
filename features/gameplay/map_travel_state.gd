extends RefCounted
## Local per-profile checkpoints. Live casts, movement input and velocity are never saved.

static func valid_point(value: Variant) -> bool:
 return value is Vector3 and value.is_finite() and value.length_squared() < 100000.0 * 100000.0

static func valid(value: Variant) -> bool:
 if not value is Dictionary or value.get("v") != 1 or not valid_point(value.get("player")) or not value.get("aboard") is bool: return false
 for key in ["yaw", "camera_yaw", "camera_pitch"]:
  if not (value.get(key) is float or value.get(key) is int) or not is_finite(float(value[key])): return false
 var boat: Variant = value.get("boat")
 if not boat is Dictionary: return false
 if boat.is_empty(): return not value.aboard
 return valid_point(boat.get("position")) and (boat.get("yaw") is float or boat.get("yaw") is int) and is_finite(float(boat.yaw))

static func clean_memory(value: Variant) -> Dictionary:
 var result := {}
 if value is Dictionary:
  for map_id in value:
   if map_id is String and FishingJournal.known_map(map_id) and valid(value[map_id]): result[map_id] = value[map_id].duplicate(true)
 return result

static func capture(player: AnglerPlayer, boat: FishingBoat, camera: AnglerCameraRig) -> Dictionary:
 # Local transforms remain readable during the parent's exit-tree notification.
 var result := {"v":1,"player":player.position,"yaw":player.visual.rotation.y,
  "camera_yaw":camera.rotation.y,"camera_pitch":camera.rotation.x,"aboard":false,"boat":{}}
 if player.boat != null and is_instance_valid(boat):
  # A hull is a session deployment, not a saved world object. Return in the water.
  var water_point: Vector3 = boat.water_exit_point
  if boat.is_inside_tree() and player.is_inside_tree():
   water_point = boat.find_water_exit()
   if not water_point.is_finite(): water_point = boat.find_shore_exit()
  elif not water_point.is_finite() and boat.exit_point.is_finite(): water_point = boat.exit_point
  if water_point.is_finite(): result.player = water_point
  else:
   result.player = player.position
   result.player.y = player.pond.definition.surface_height() - player.swim_float_depth
 return result if valid(result) else {}

static func _within_map(point: Vector3, definition: PondDefinition) -> bool:
 return definition.constrain_travel(point).distance_to(point) < 0.1

static func _clear(actor: CollisionObject3D, point: Vector3, yaw: float, exclusions: Array[RID]) -> bool:
 var shape := actor.get_node("CollisionShape3D") as CollisionShape3D
 var transform := Transform3D(Basis(Vector3.UP,yaw),point) * shape.transform
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = shape.shape
 query.transform = transform
 query.exclude = exclusions
 query.collision_mask = 1
 return actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

static func _supported(player: AnglerPlayer, point: Vector3) -> bool:
 var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * .15,point - Vector3.UP * 200)
 query.exclude = [player.get_rid()]
 var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty(): return false
 var definition := player.pond.definition
 return point.y - hit.position.y <= 25.0 or (definition.can_swim_at(point) and absf(point.y - definition.surface_height()) < 2.0)

static func restore(value: Dictionary, player: AnglerPlayer, boat: FishingBoat, camera: AnglerCameraRig) -> bool:
 if not valid(value) or not is_instance_valid(player.pond): return false
 var definition := player.pond.definition
 # Ignore hulls in older checkpoints too; owning a boat never auto-deploys it.
 if is_instance_valid(boat): boat.set_deployed(false)
 var restored := false
 var point: Vector3 = value.player
 if value.aboard: point.y = definition.surface_height() - player.swim_float_depth
 if _within_map(point,definition) and _supported(player,point) and _clear(player,point,0,[player.get_rid()]):
  player.position = point
  restored = true
 if restored:
  player.velocity = Vector3.ZERO
  player.run_requested = false
  player.visual.rotation.y = wrapf(float(value.yaw),-PI,PI)
  player._update_swimming()
  camera.rotation = Vector3(clampf(float(value.camera_pitch),deg_to_rad(camera.min_pitch),deg_to_rad(camera.max_pitch)),wrapf(float(value.camera_yaw),-PI,PI),0)
  camera.position = player.position
  camera.reset_input()
 return restored
