class_name PondDefinition
extends Resource

## Geometry rules in world coordinates. Fish Y is positive depth.
@export var water_bounds := Rect2(-85, -95, 170, 96.2)
@export var dock_clearance := Rect2(-2.65, -9.2, 5.3, 10.4)
@export var walking_z := Vector2(-8.5, 12.0)
@export var dock_walk_half_width: float = 1.65
@export var bank_walk_half_width: float = 16.0
@export var bank_start_z: float = 2.5
@export var max_landing_edge_distance: float = 6.5
@export var landing_reach: float = 2.4

func constrain_to_water(point: Vector3) -> Vector3:
 point.x = clampf(point.x, water_bounds.position.x, water_bounds.end.x)
 point.z = clampf(point.z, water_bounds.position.y, water_bounds.end.y)
 if dock_clearance.has_point(Vector2(point.x, point.z)):
  var side_distance := dock_clearance.end.x - absf(point.x)
  var tip_distance := point.z - dock_clearance.position.y
  if tip_distance <= side_distance:
   point.z = dock_clearance.position.y
  else:
   point.x = dock_clearance.end.x if point.x >= 0 else dock_clearance.position.x
 return point

func water_depth_at(_point: Vector2) -> float:
 return 12.0

func is_castable(point: Vector3) -> bool:
 return point.distance_to(constrain_to_water(point)) <= 0.05

func spawn_position(rng: RandomNumberGenerator, depths: Vector2, slot: int) -> Vector3:
 var point := Vector3(rng.randf_range(-17, 17), rng.randf_range(depths.x, depths.y), rng.randf_range(-28, -10))
 if slot >= 0 and slot < 9:
  point = Vector3(float(slot % 3 - 1) * 2.8, (depths.x + depths.y) * 0.5, -15.0 - float(slot / 3) * 3.0)
 return point

func roaming_position(rng: RandomNumberGenerator, _current: Vector3, depths: Vector2) -> Vector3:
 return Vector3(rng.randf_range(-21, 21), rng.randf_range(depths.x, depths.y), rng.randf_range(-31, -10))

func is_wading(_point: Vector3) -> bool:
 return false

func constrain_walking(point: Vector3) -> Vector3:
 point.z = clampf(point.z, walking_z.x, walking_z.y)
 var half_width := dock_walk_half_width if point.z < bank_start_z else bank_walk_half_width
 point.x = clampf(point.x, -half_width, half_width)
 return point

func can_land_fish(angler: Vector3, fish_position: Vector3, fish_distance: float) -> bool:
 var edge := constrain_to_water(angler)
 if absf(angler.x) < dock_clearance.end.x and angler.z < bank_start_z and fish_position.z <= dock_clearance.position.y + 0.1:
  edge = Vector3(angler.x, angler.y, dock_clearance.position.y)
 var edge_distance := planar_distance(angler, edge)
 return edge_distance <= max_landing_edge_distance and fish_distance <= maxf(landing_reach, edge_distance + 0.8) and planar_distance(fish_position, edge) < landing_reach

static func planar_distance(a: Vector3, b: Vector3) -> float:
 return Vector2(a.x - b.x, a.z - b.z).length()
