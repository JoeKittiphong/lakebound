class_name RegionDefinition
extends RiverDefinition
## Shared by authored terrain, swimming, boats and fish.
@export_enum("marsh", "stream", "reservoir", "estuary", "ocean") var region_kind: String="marsh"
@export var basin_radii:=Vector2(64,52)
@export var maximum_depth: float=3.0
@export var shore_transition: float=14.0
@export var dock_origin:=Vector2(-64,20)
@export var dock_along_x:=true
func center_at(z: float) -> float:
 return 8*sin(z/22.0) if region_kind=="stream" else 9*sin(z/31.0) if region_kind=="estuary" else 0.0
func half_width_at(z: float) -> float:
 if region_kind=="stream":return 12+3*sin(z/18.0)
 if region_kind=="estuary":return 29+8*sin(z/26.0)
 return basin_radii.x*sqrt(maxf(.01,1-pow(z/basin_radii.y,2)))
func edge_distance(p: Vector2) -> float:
 if region_kind=="ocean":return p.y-32.0+2.0*sin(p.x/27.0)
 if region_kind in ["stream","estuary"]:return absf(p.x-center_at(p.y))-half_width_at(p.y)
 return (Vector2(p.x/basin_radii.x,p.y/basin_radii.y).length()-1)*minf(basin_radii.x,basin_radii.y)
func ground_height(p: Vector2) -> float:
 var d:=edge_distance(p)
 var h:=water_height+.14*d if d>=0 else water_height-.06-maximum_depth*smoothstep(0,shore_transition,-d)
 if d>8:h=water_height+1.12+(d-8)*.045+.18*sin(p.x*.12)*sin(p.y*.10)
 return maxf(h,island_height(p))
func on_bridge(_p: Vector3) -> bool:return false
func on_jetty(p: Vector3) -> bool:
 if p.y<.25:return false
 return (absf(p.z-dock_origin.y)<1.45 and p.x>dock_origin.x-.1 and p.x<dock_origin.x+9.6) if dock_along_x else (absf(p.x-dock_origin.x)<1.45 and p.z<dock_origin.y+.1 and p.z>dock_origin.y-9.6)
func constrain_travel(p: Vector3) -> Vector3:
 p.x=clampf(p.x,walking_bounds.position.x,walking_bounds.end.x)
 p.z=clampf(p.z,walking_bounds.position.y,walking_bounds.end.y)
 return p
func constrain_walking(p: Vector3) -> Vector3:return constrain_travel(p)
func constrain_to_water(p: Vector3) -> Vector3:
 p.x=clampf(p.x,water_bounds.position.x+1,water_bounds.end.x-1)
 p.z=clampf(p.z,water_bounds.position.y+1,water_bounds.end.y-1)
 if region_kind=="ocean":p.z=minf(p.z,27-2*sin(p.x/27.0))
 elif region_kind in ["stream","estuary"]:
  var c:=center_at(p.z);var w:=half_width_at(p.z)-2
  p.x=clampf(p.x,c-w,c+w)
 else:
  var ellipse:=Vector2(p.x/basin_radii.x,p.z/basin_radii.y)
  if ellipse.length()>.94:
   ellipse=ellipse.normalized()*.94;p.x=ellipse.x*basin_radii.x;p.z=ellipse.y*basin_radii.y
 for island in islands:
  var offset:=Vector2((p.x-island.x)/island.z,(p.z-island.y)/island.w)
  if offset.length()<1.12:
   if offset.length()<.01:offset=Vector2.RIGHT
   offset=offset.normalized()*1.18;p.x=island.x+offset.x*island.z;p.z=island.y+offset.y*island.w
 p.y=clampf(p.y,.05,maxf(.05,water_depth_at(Vector2(p.x,p.z))-.10))
 return p
func spawn_position(rng: RandomNumberGenerator,depths: Vector2,slot: int) -> Vector3:
 var p:=Vector3(rng.randf_range(-basin_radii.x*.8,basin_radii.x*.8),rng.randf_range(depths.x,depths.y),rng.randf_range(-basin_radii.y*.8,basin_radii.y*.8))
 if slot>=0 and slot<12:
  p=Vector3(dock_origin.x+8+rng.randf_range(2,12),p.y,dock_origin.y+rng.randf_range(-8,8)) if dock_along_x else Vector3(rng.randf_range(-10,10),p.y,dock_origin.y-rng.randf_range(13,28))
 return constrain_to_water(p)
func roaming_position(rng: RandomNumberGenerator,current: Vector3,depths: Vector2) -> Vector3:
 return constrain_to_water(current+Vector3(rng.randf_range(-12,12),0,rng.randf_range(-12,12))+Vector3(0,rng.randf_range(depths.x,depths.y)-current.y,0))
func is_castable(p: Vector3) -> bool:
 return water_depth_at(Vector2(p.x,p.z))>.12 and p.distance_to(constrain_to_water(p))<.05
