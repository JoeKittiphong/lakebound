class_name RainforestLakeDefinition
extends RiverDefinition
## All coordinates are X/Z metres. The geometry builder, movement and fish share this resource.
@export var main_lake := Vector4(-5, 4, 412, 184)
@export var pools: Array[Vector4] = [Vector4(-420,-177,46,28),Vector4(397,-166,82,54),Vector4(414,179,72,46)]
@export var lake_outline:=PackedVector2Array([Vector2(-453,-36),Vector2(-431,-95),Vector2(-376,-112),Vector2(-350,-151),Vector2(-302,-161),Vector2(-265,-205),Vector2(-205,-212),Vector2(-164,-169),Vector2(-108,-185),Vector2(-65,-220),Vector2(-8,-214),Vector2(30,-174),Vector2(92,-182),Vector2(137,-212),Vector2(187,-198),Vector2(207,-158),Vector2(267,-159),Vector2(302,-128),Vector2(345,-118),Vector2(383,-76),Vector2(367,-23),Vector2(405,23),Vector2(445,52),Vector2(443,98),Vector2(396,127),Vector2(344,129),Vector2(314,169),Vector2(273,197),Vector2(221,216),Vector2(173,201),Vector2(146,175),Vector2(105,197),Vector2(77,226),Vector2(12,232),Vector2(-31,214),Vector2(-62,185),Vector2(-112,199),Vector2(-165,222),Vector2(-226,227),Vector2(-269,211),Vector2(-307,215),Vector2(-337,187),Vector2(-378,220),Vector2(-431,221),Vector2(-467,189),Vector2(-459,152),Vector2(-426,119),Vector2(-429,65),Vector2(-413,18)])
@export var shoreline_field: Image
@export var fish_habitats:=PackedVector3Array()
var _fish_habitat_cache: Dictionary={}
@export var cave_enabled:=true
@export var cave_bounds:=Rect2(-4,-246,88,74)
@export var cave_pool:=Vector4(40,-215,25,25)
@export var cave_mouth:=Vector2(40,-172)
@export var cave_depth:=4.0
@export var lake_islands: Array[Vector4] = [Vector4(-133,0,66,48),Vector4(175,-17,39,31),Vector4(66,104,32,24)]
@export var channel_starts: Array[Vector2] = [Vector2(-378,-153),Vector2(367,-131),Vector2(373,151)]
@export var channel_ends: Array[Vector2] = [Vector2(-338,-101),Vector2(326,-85),Vector2(320,107)]
@export var channel_half_width := 12.0
@export_range(8.0,48.0,1.0) var shallow_shelf_width := 28.0
@export_range(.3,1.5,.05) var shallow_shelf_depth := .80
@export var arrival := Vector2(-320,132)
@export var spawn_shore := Vector2(-324,143)
@export var jetty_rect := Rect2(-322,107,4,26)

func _init() -> void:
 water_bounds = Rect2(-500,-250,1000,500)
 walking_bounds = Rect2(-498,-248,996,496)
 water_height = -0.18
 islands = []

static func ellipse_distance(p: Vector2, e: Vector4) -> float:
 return (Vector2((p.x-e.x)/e.z,(p.y-e.y)/e.w).length()-1.0)*minf(e.z,e.w)

static func segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
 var v := b-a
 return p.distance_to(a+v*clampf((p-a).dot(v)/maxf(v.length_squared(),.001),0,1))

static func polygon_distance(p: Vector2,outline: PackedVector2Array) -> float:
 var distance_squared:=INF
 for i in outline.size():
  var a:=outline[i];var v:=outline[(i+1)%outline.size()]-a
  var closest:=a+v*clampf((p-a).dot(v)/maxf(v.length_squared(),.001),0,1)
  distance_squared=minf(distance_squared,p.distance_squared_to(closest))
 return sqrt(distance_squared)*(-1 if Geometry2D.is_point_in_polygon(p,outline) else 1)

func previous_water_distance(p: Vector2) -> float:
 var d:=ellipse_distance(p,main_lake)+6*sin(p.x*.025)*sin(p.y*.033)+3.5*sin(p.x*.056+p.y*.039)
 for pool in [Vector4(-412,-177,58,40),Vector4(403,-160,66,48),Vector4(410,176,64,43)]:d=minf(d,ellipse_distance(p,pool))
 for i in channel_starts.size():d=minf(d,segment_distance(p,channel_starts[i],channel_ends[i])-channel_half_width)
 for island in lake_islands:d=maxf(d,-ellipse_distance(p,island))
 return d

func raw_water_distance(p: Vector2) -> float:
 var shoreline:=polygon_distance(p,lake_outline)
 shoreline+=2.6*sin(p.x*.071+p.y*.049)+1.4*sin(p.y*.121-p.x*.043)
 # Distinct backwater, long northeast basin and lobed southeast wetland.
 for i in pools.size():
  var pool:=pools[i]
  var q:=p+Vector2(4*sin(p.y*.045+i),3*sin(p.x*.05-i))
  shoreline=minf(shoreline,ellipse_distance(q,pool))
 for lobe in [Vector4(-441,-184,27,18),Vector4(441,-197,40,27),Vector4(453,158,33,31),Vector4(378,210,46,25)]:shoreline=minf(shoreline,ellipse_distance(p,lobe))
 for i in channel_starts.size():shoreline=minf(shoreline,segment_distance(p,channel_starts[i],channel_ends[i])-channel_half_width)
 # A crooked land spur retains a dry connection to the southwest arrival shore.
 var spur:=minf(segment_distance(p,Vector2(-500,142),Vector2(-412,139))-14,segment_distance(p,Vector2(-412,139),Vector2(-338,153))-17)
 shoreline=maxf(shoreline,-spur)
 # Land fingers break the pool rims into unequal coves rather than round basins.
 for finger in [Vector4(-500,-177,-443,-173),Vector4(500,-135,441,-151),Vector4(500,205,438,188)]:
  shoreline=maxf(shoreline,-(segment_distance(p,Vector2(finger.x,finger.y),Vector2(finger.z,finger.w))-9))
 for i in lake_islands.size():
  var island_distance:=ellipse_distance(p,lake_islands[i])+2.4*sin(p.x*.083+p.y*.063)+1.3*sin(p.y*.14-p.x*.06)
  var lobes: Array[Vector4]=[Vector4(-185,-34,44,22),Vector4(194,-28,32,19),Vector4(79,117,28,16)]
  island_distance=minf(island_distance,ellipse_distance(p,lobes[i]))
  var notches: Array[Vector4]=[Vector4(-134,-42,28,19),Vector4(194,-6,17,18),Vector4(52,87,18,12)]
  island_distance=maxf(island_distance,-ellipse_distance(p,notches[i]))
  shoreline=maxf(shoreline,-island_distance)
 var result:=lerpf(shoreline,previous_water_distance(p),infrastructure_retention(p))
 if cave_enabled:result=minf(result,cave_water_distance(p))
 return result

func infrastructure_retention(p: Vector2) -> float:
 # Preserve working shore/deck/bridge approaches within their local corridors.
 var retained:=1-smoothstep(8,22,segment_distance(p,Vector2(-320,148),Vector2(-320,108)))
 for i in channel_starts.size():
  var middle:=channel_starts[i].lerp(channel_ends[i],.5)
  var direction: Vector2=(channel_ends[i]-channel_starts[i]).normalized()
  var offset:=p-middle
  var corridor: float=(1-smoothstep(8,24,absf(offset.dot(direction))))*(1-smoothstep(44,68,absf(offset.dot(Vector2(-direction.y,direction.x)))))
  retained=maxf(retained,corridor)
 return retained

func bake_shoreline() -> Image:
 fish_habitats.clear();_fish_habitat_cache.clear()
 var field:=Image.create(501,251,false,Image.FORMAT_RF)
 for z in 251:
  for x in 501:field.set_pixel(x,z,Color(raw_water_distance(Vector2(x*2-500,z*2-250)),0,0,1))
 shoreline_field=field
 return field

func signed_water_distance(p: Vector2) -> float:
 if shoreline_field==null:return raw_water_distance(p)
 # CPU float field keeps movement/fish queries cheap; source polygon stays editable.
 var uv:=(p+Vector2(500,250))*.5
 var q:=uv.clamp(Vector2.ZERO,Vector2(500,250))
 var x:=mini(floori(q.x),499);var z:=mini(floori(q.y),249)
 var tx:=q.x-x;var tz:=q.y-z
 var upper:=lerpf(shoreline_field.get_pixel(x,z).r,shoreline_field.get_pixel(x+1,z).r,tx)
 var lower:=lerpf(shoreline_field.get_pixel(x,z+1).r,shoreline_field.get_pixel(x+1,z+1).r,tx)
 return lerpf(upper,lower,tz)+p.distance_to(Vector2(q.x*2-500,q.y*2-250))

func in_cave_area(p: Vector2) -> bool:
 return cave_enabled and cave_bounds.has_point(p)

func cave_water_distance(p: Vector2) -> float:
 return minf(ellipse_distance(p,cave_pool),segment_distance(p,Vector2(cave_mouth.x,-150),Vector2(cave_pool.x,cave_pool.y))-13)

func ground_height(p: Vector2) -> float:
 var d := signed_water_distance(p)
 if in_cave_area(p):
  if d<0:return water_height-.04-(cave_depth-.04)*smoothstep(0,10,-d)
  return water_height+.06+minf(d,7)*.11
 if d < 0:
  var inside:=-d
  var width:=shallow_shelf_width+5*sin(p.x*.018+p.y*.027)
  var depth:=lerpf(.04,shallow_shelf_depth,smoothstep(0,width,inside))
  depth+=10.74*smoothstep(width,width+32,inside)
  # Satellite pools retain a deep fish habitat inside their broad planted margins.
  for pool in pools:
   var pd:=-ellipse_distance(p,pool)
   if pd>0:depth=maxf(depth,5.5*smoothstep(8,minf(pool.z,pool.w)*.82,pd))
  # Keep through-channels and the boat launch navigable after widening shallows.
  for i in channel_starts.size():
   var channel_distance:=segment_distance(p,channel_starts[i],channel_ends[i])
   depth=maxf(depth,2.4*(1-smoothstep(6,channel_half_width,channel_distance)))
  var launch_distance:=segment_distance(p,Vector2(-314,111),Vector2(-270,60))
  depth=maxf(depth,2.0*(1-smoothstep(5,10,launch_distance)))
  if cave_enabled and p.y< -138 and p.y> -230:
   var entrance_distance:=segment_distance(p,Vector2(cave_mouth.x,-140),Vector2(cave_pool.x,cave_pool.y))
   depth=maxf(depth,cave_depth*(1-smoothstep(10,13,entrance_distance)))
  return water_height-depth
 var bank := water_height+minf(d,10)*.12
 if d > 10:
  bank += .024*(d-10)+(.45*sin(p.x*.028)*sin(p.y*.033))*smoothstep(10,32,d)
 # North wooded ridge encloses the map; accessible beaches stay gently sloped.
 var old_ridge:=11*(1.0-smoothstep(-244,-183,p.y))*smoothstep(10,40,d)
 var ridge:=26*(1.0-smoothstep(-145,-110,p.y))*smoothstep(2,27,d)
 bank += lerpf(ridge,old_ridge,infrastructure_retention(p))
 return bank

func water_depth_at(p: Vector2) -> float:
 return maxf(0,water_height-ground_height(p))

func surface_height() -> float:
 return water_height

func constrain_travel(p: Vector3) -> Vector3:
 p.x = clampf(p.x,walking_bounds.position.x,walking_bounds.end.x)
 p.z = clampf(p.z,walking_bounds.position.y,walking_bounds.end.y)
 return p

func constrain_to_water(p: Vector3) -> Vector3:
 var q := Vector2(p.x,p.z)
 # Descend the common shoreline field; handles islands, pools and channels identically.
 for i in 32:
  var d := signed_water_distance(q)
  if d < -2: break
  var gradient := Vector2(signed_water_distance(q+Vector2(.5,0))-signed_water_distance(q-Vector2(.5,0)),signed_water_distance(q+Vector2(0,.5))-signed_water_distance(q-Vector2(0,.5)))
  if gradient.length_squared()<.00001: gradient=q-Vector2(main_lake.x,main_lake.y)
  q -= gradient.normalized()*clampf(d+3,1,25)
 p.x=q.x
 p.z=q.y
 p.y=clampf(p.y,.10,maxf(.10,water_depth_at(q)-.12))
 return p

func constrain_walking(p: Vector3) -> Vector3:
 return constrain_travel(p)

func can_swim_at(p: Vector3) -> bool:
 return water_bounds.has_point(Vector2(p.x,p.z)) and water_depth_at(Vector2(p.x,p.z))>.85 and not on_jetty(p) and not on_bridge(p)

func on_bridge(_p: Vector3) -> bool:
 return false

func on_jetty(p: Vector3) -> bool:
 return jetty_rect.has_point(Vector2(p.x,p.z)) and p.y>.1

func is_wading(p: Vector3) -> bool:
 var depth := water_depth_at(Vector2(p.x,p.z))
 return depth>.1 and depth<=.65 and p.y<water_height+.12 and not on_jetty(p)

func is_castable(p: Vector3) -> bool:
 return water_depth_at(Vector2(p.x,p.z))>.25 and not on_jetty(Vector3(p.x,.4,p.z))

func bake_fish_habitats() -> void:
 fish_habitats.clear();_fish_habitat_cache.clear()
 for iz in 27:
  for ix in 55:
   var p:=Vector2(-486+ix*18,-234+iz*18)
   var depth:=water_depth_at(p)
   if signed_water_distance(p)> -2 or depth<.35:continue
   if depth>2.2 and (ix%2!=0 or iz%2!=0):continue
   fish_habitats.append(Vector3(p.x,depth,p.y))
 for z in [-229.,-219.,-209.,-199.]:
  for x in [25.,35.,45.,55.]:
   var p:=Vector2(x,z);var depth:=water_depth_at(p)
   if depth>.5:fish_habitats.append(Vector3(x,depth,z))
 # Keep accessible fish around the original jetty as well as remote habitats.
 for x in [-328.,-319.,-310.,-301.]:
  for z in [99.,108.]:
   var p:=Vector2(x,z);var depth:=water_depth_at(p)
   if signed_water_distance(p)< -2 and depth>.5:fish_habitats.append(Vector3(x,depth,z))

func habitat_group(p: Vector3) -> int:
 if in_cave_area(Vector2(p.x,p.z)):return 0
 for i in pools.size():
  if ellipse_distance(Vector2(p.x,p.z),pools[i])<2:return i+1
 return 4 if p.y<=2.2 else 5

func _habitat_indices(depths: Vector2,group: int) -> Array[int]:
 if fish_habitats.is_empty():bake_fish_habitats()
 var key:=Vector3(depths.x,depths.y,group)
 if not _fish_habitat_cache.has(key):
  var indices: Array[int]=[]
  for i in fish_habitats.size():
   if fish_habitats[i].y>=depths.x+.25 and (group<0 or habitat_group(fish_habitats[i])==group):indices.append(i)
  _fish_habitat_cache[key]=indices
 return _fish_habitat_cache[key]

func _spawn_habitat(rng: RandomNumberGenerator,depths: Vector2,group: int) -> Vector3:
 var candidates:=_habitat_indices(depths,group)
 if candidates.is_empty():candidates=_habitat_indices(depths,-1)
 if candidates.is_empty():return constrain_to_water(Vector3(0,depths.x,0))
 var anchor:=fish_habitats[candidates[rng.randi_range(0,candidates.size()-1)]]
 var p:=Vector2(anchor.x,anchor.z)
 for attempt in 8:
  var q:=p+Vector2(rng.randf_range(-5,5),rng.randf_range(-5,5))
  if signed_water_distance(q)< -2 and water_depth_at(q)>depths.x+.25:p=q;break
 var available:=water_depth_at(p)-.2
 return Vector3(p.x,rng.randf_range(minf(depths.x,available),minf(depths.y,available)),p.y)

func spawn_position(rng: RandomNumberGenerator,depths: Vector2,slot: int) -> Vector3:
 var cycle: Array[int]=[4,4,5,4,1,4,5,2,4,0,5,3]
 var index: int=(slot+floori(slot/17.0))%cycle.size() if slot>=0 else rng.randi_range(0,cycle.size()-1)
 return _spawn_habitat(rng,depths,cycle[index])

func spawn_cave_position(rng: RandomNumberGenerator,depths: Vector2) -> Vector3:
 return _spawn_habitat(rng,depths,0)

func roaming_position(rng: RandomNumberGenerator,current: Vector3,depths: Vector2) -> Vector3:
 for attempt in 4:
  var candidate:=constrain_to_water(current+Vector3(rng.randf_range(-10,10),rng.randf_range(depths.x,depths.y)-current.y,rng.randf_range(-10,10)))
  if water_depth_at(Vector2(candidate.x,candidate.z))>=depths.x+.2:return candidate
 return constrain_to_water(current)

func can_land_fish(angler: Vector3,fish_position: Vector3,distance: float) -> bool:
 var edge := constrain_to_water(angler)
 var edge_distance := planar_distance(angler,edge)
 # The long arrival jetty crosses shallow water before the deep fishing edge.
 var allowed_edge:=12.0 if on_jetty(angler) else max_landing_edge_distance
 return edge_distance<=allowed_edge and distance<=maxf(landing_reach,edge_distance+.8) and planar_distance(fish_position,edge)<landing_reach
