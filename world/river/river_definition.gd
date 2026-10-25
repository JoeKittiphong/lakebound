class_name RiverDefinition
extends PondDefinition

@export var water_height: float = -0.18
@export var bridge_z: float = -116.0
@export var ford_z: float = 108.0
@export var max_wading_depth: float = 0.60
@export var islands: Array[Vector4] = [Vector4(46, -24, 10, 23), Vector4(42, -65, 6, 12)]
@export var walking_bounds := Rect2(-142, -124, 284, 240)

func center_at(z: float) -> float:
 return 12.0 * sin((z + 20.0) / 85.0) + 5.0 * sin(z / 35.0)

func half_width_at(z: float) -> float:
 return 30.0 + 62.0 * exp(-pow((z + 5.0) / 95.0, 2.0)) + 18.0 * exp(-pow((z - 115.0) / 40.0, 2.0))

func island_height(point: Vector2) -> float:
 var best := -100.0
 for island in islands:
  var r := Vector2((point.x - island.x) / island.z, (point.y - island.y) / island.w).length()
  var h: float
  if r < 0.75:
   h = 0.72 + 0.16 * (1.0 - pow(r / 0.75, 2))
  elif r < 1.0:
   h = lerpf(0.72, water_height - 0.08, smoothstep(0.75, 1.0, r))
  else:
   h = water_height - 0.08 - 8.0 * (r - 1.0)
  best = maxf(best, h)
 return best

func ground_height(point: Vector2) -> float:
 var x := point.x
 var z := point.y
 var d := absf(x - center_at(z)) - half_width_at(z)
 var h: float
 if d >= 0.0:
  h = water_height + 0.16 * d
  if d > 7.0:
   h = water_height + 1.12 + 0.055 * (d - 7.0) + 0.12 * sin(x * 0.07) * sin(z * 0.08) * smoothstep(8.0, 20.0, d)
 else:
  var depth := 0.05 + 12.0 * smoothstep(0.0, 24.0, -d)
  var shallow := 0.34 + 0.035 * sin(x * 0.14)
  var ford_center := ford_z + 5.0 * sin((x - center_at(ford_z)) * 0.035)
  depth = lerpf(shallow, depth, smoothstep(10.0, 18.0, absf(z - ford_center)))
  if x > 45.0 and x < center_at(z) + half_width_at(z) + 2.0:
   var side := smoothstep(4.0, 10.0, absf(z + 24.0))
   depth = minf(depth, lerpf(0.36, depth, side))
  h = water_height - depth
 return maxf(h, island_height(point))

func water_depth_at(point: Vector2) -> float:
 return maxf(0.0, water_height - ground_height(point))

func bridge_half_length() -> float:
 return ceilf((half_width_at(bridge_z) + 3.0) / 6.0) * 6.0

func on_bridge(point: Vector3) -> bool:
 return absf(point.z - bridge_z) <= 1.85 and absf(point.x - center_at(bridge_z)) <= bridge_half_length() + 8.0 and point.y > 0.35

func on_jetty(point: Vector3) -> bool:
 var edge := center_at(24) + half_width_at(24)
 return absf(point.z - 24.0) < 1.48 and point.x > edge - 8.6 and point.x < edge + 5.0 and point.y > 0.2

func constrain_to_water(point: Vector3) -> Vector3:
 point.z = clampf(point.z, -150.0, 150.0)
 var c := center_at(point.z)
 var w := half_width_at(point.z)
 if absf(point.x - c) > w - 2.0:
  point.x = c + (1.0 if point.x >= c else -1.0) * (w - 2.0)
 for island in islands:
  var offset := Vector2((point.x - island.x) / island.z, (point.z - island.y) / island.w)
  if offset.length() < 1.08:
   if offset.length_squared() < 0.0001:
    offset = Vector2.RIGHT
   offset = offset.normalized() * 1.14
   point.x = island.x + offset.x * island.z
   point.z = island.y + offset.y * island.w
 var depth := water_depth_at(Vector2(point.x, point.z))
 point.y = clampf(point.y, 0.10, maxf(0.10, depth - 0.12))
 return point

func surface_height() -> float:
 return water_height

func can_swim_at(point: Vector3) -> bool:
 return water_bounds.has_point(Vector2(point.x, point.z)) and water_depth_at(Vector2(point.x, point.z)) > 0.85 and not on_bridge(point) and not on_jetty(point)

func constrain_travel(point: Vector3) -> Vector3:
 point.x = clampf(point.x, walking_bounds.position.x, walking_bounds.end.x)
 point.z = clampf(point.z, walking_bounds.position.y, walking_bounds.end.y)
 var c := center_at(point.z)
 var w := half_width_at(point.z)
 point.x = clampf(point.x, c - w - 28.0, c + w + 28.0)
 return point

func constrain_walking(point: Vector3) -> Vector3:
 point = constrain_travel(point)
 var c := center_at(point.z)
 var w := half_width_at(point.z)
 if not on_bridge(point) and not on_jetty(point) and water_depth_at(Vector2(point.x, point.z)) > max_wading_depth:
  # Movement is constrained at the nearest bank; physics still owns height.
  var side := 1.0 if point.x >= c else -1.0
  var inside := 0.0
  for step in 40:
   var candidate := c + side * (w - float(step) * 0.15)
   if water_depth_at(Vector2(candidate, point.z)) > max_wading_depth:
    break
   inside = float(step) * 0.15
  point.x = c + side * (w - maxf(0.0, inside - 0.20))
 return point

func is_wading(point: Vector3) -> bool:
 var depth := water_depth_at(Vector2(point.x, point.z))
 return depth > 0.10 and depth <= max_wading_depth + 0.1 and not on_bridge(point) and not on_jetty(point) and point.y < water_height + 0.1

func is_castable(point: Vector3) -> bool:
 var bounds := Rect2(center_at(bridge_z) - bridge_half_length(), bridge_z - 2.0, bridge_half_length() * 2, 4)
 if bounds.has_point(Vector2(point.x, point.z)):
  return false
 return water_depth_at(Vector2(point.x, point.z)) > 0.22 and point.distance_to(constrain_to_water(point)) < 0.05

func spawn_position(rng: RandomNumberGenerator, depths: Vector2, slot: int) -> Vector3:
 var site := int(maxi(slot, 0) / 16) % 7 if slot >= 0 else rng.randi_range(0, 6)
 var z: float = [42.0, -28.0, 68.0, 22.0, -72.0, 72.0, -100.0][site]
 var side := -1.0 if site < 3 else 1.0
 z += rng.randf_range(-4.0, 4.0)
 var x := center_at(z) + side * (half_width_at(z) - rng.randf_range(9.0, 17.0))
 if site == 6:
  x = center_at(z) + rng.randf_range(-5.0, 5.0)
 return constrain_to_water(Vector3(x, rng.randf_range(depths.x, depths.y), z))

func roaming_position(rng: RandomNumberGenerator, current: Vector3, depths: Vector2) -> Vector3:
 for attempt in 12:
  var p := Vector3(current.x + rng.randf_range(-12, 12), rng.randf_range(depths.x, depths.y), current.z + rng.randf_range(-12, 12))
  var safe := constrain_to_water(p)
  if water_depth_at(Vector2(safe.x, safe.z)) >= minf(depths.x + 0.3, 3.0):
   return safe
 return constrain_to_water(current)

func can_land_fish(angler: Vector3, fish_position: Vector3, fish_distance: float) -> bool:
 var edge := constrain_to_water(angler)
 var edge_distance := planar_distance(angler, edge)
 return edge_distance <= max_landing_edge_distance and fish_distance <= maxf(landing_reach, edge_distance + 0.8) and planar_distance(fish_position, edge) < landing_reach


