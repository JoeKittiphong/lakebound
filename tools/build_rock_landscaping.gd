extends SceneTree
var world: Node3D
var definition: RiverDefinition
var rng:=RandomNumberGenerator.new()
var assets: Array[String]=[]
var placements: Array[Dictionary]=[]
var footprints: Array[Vector3]=[]
func _initialize() -> void:call_deferred("run")
func ground(p: Vector2) -> float:
 var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,30,p.y),Vector3(p.x,-40,p.y))
 for attempt in 20:
  var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty():return definition.ground_height(p)
  if hit.collider.name=="GroundCollision":return hit.position.y
  query.exclude.append(hit.collider.get_rid())
 return definition.ground_height(p)
func safe(p: Vector2,r: float) -> bool:
 if absf(p.y-definition.bridge_z)<13+r or absf(p.y-definition.ford_z)<13+r:return false
 if p.distance_to(Vector2(-69.52561,42))<13+r or p.distance_to(Vector2(-64,35))<13+r:return false
 if p.distance_to(Vector2(96.68943,24))<17+r:return false
 # Leave the central boat corridor open.
 if absf(p.x-definition.center_at(p.y))<12+r:return false
 for f in footprints:
  if p.distance_to(Vector2(f.x,f.y))<r+f.z+1.0:return false
 return true
func run() -> void:
 rng.seed=251026
 world=load("res://world/river/river_world.tscn").instantiate()
 root.add_child(world);definition=world.definition
 if world.has_node("RockLandscaping"):world.get_node("RockLandscaping").queue_free()
 for frame in 8:await physics_frame
 assets.append("res://world/river/props/rock_mobile.tscn")
 for i in range(1,8):assets.append("res://world/river/props/reference_rocks/rock_%02d.tscn"%i)
 for i in range(1,7):assets.append("res://world/river/props/concept_rocks_01_06/rock_%02d.tscn"%i)
 for name in ["rock_20","rock_21","pebble_01","pebble_02","pebble_03"]:assets.append("res://world/river/props/rock_clusters_20_21/"+name+".tscn")
 var text:="[gd_scene format=3]\n"
 for i in assets.size():text+='[ext_resource type="PackedScene" path="%s" id="r%d"]\n'%[assets[i],i]
 text+='[node name="RockLandscaping" type="Node3D"]\n'
 for zone in ["Land","Shore","Shallow","Deep"]:
  text+='[node name="%s" type="Node3D" parent="."]\n'%zone
  for slot in 38:
   var id:=slot%assets.size()
   var template: Node3D=load(assets[id]).instantiate()
   var meshes:=template.find_children("*","MeshInstance3D",true,false)
   var bounds:=AABB()
   var first:=true
   for mesh: MeshInstance3D in meshes:
    var box: AABB=mesh.transform*mesh.get_aabb()
    bounds=box if first else bounds.merge(box);first=false
   var scale_value:=rng.randf_range(.7,1.5)
   if zone=="Deep":scale_value*=1.7
   if id>=16:scale_value*=rng.randf_range(1.2,2.0)
   var radius:=Vector2(bounds.size.x,bounds.size.z).length()*.5*scale_value
   var point:=Vector2.ZERO
   var found:=false
   var depth:=0.0
   for attempt in 300:
    var z:=rng.randf_range(-143,142)
    var side: float=-1 if slot%2==0 else 1
    var offset: float
    match zone:
     "Land":offset=rng.randf_range(9,23)
     "Shore":offset=rng.randf_range(.0,2.8)
     "Shallow":offset=-rng.randf_range(.6,4.5)
     _:offset=-rng.randf_range(8,32)
    point=Vector2(definition.center_at(z)+side*(definition.half_width_at(z)+offset),z)
    depth=definition.water_depth_at(point)
    if zone=="Land" and depth>0:continue
    if zone=="Shore" and depth>.15:continue
    if zone=="Shallow" and (depth<.15 or depth>1.4):continue
    if zone=="Deep" and depth<3.0:continue
    if not safe(point,radius):continue
    found=true;break
   assert(found,"No placement for "+zone+str(slot))
   var yaw:=rng.randf_range(-PI,PI)
   # Sample footprint against the actual collision terrain, partly burying each base.
   var base:=ground(point)
   for angle in 8:
    var p:=point+Vector2.from_angle(TAU*angle/8.0)*radius*.65
    base=minf(base,ground(p))
   base-=.05*scale_value
   base-=bounds.position.y*scale_value
   var name:="%s_%02d"%[zone,slot]
   text+='[node name="%s" parent="%s" instance=ExtResource("r%d")]\nposition = Vector3(%.5f,%.5f,%.5f)\nrotation = Vector3(0,%.5f,0)\nscale = Vector3(%.5f,%.5f,%.5f)\nmetadata/habitat = "%s"\nmetadata/asset_index = %d\nmetadata/footprint_radius = %.5f\n'%[name,zone,id,point.x,base,point.y,yaw,scale_value,scale_value,scale_value,zone,id,radius]
   footprints.append(Vector3(point.x,point.y,radius))
   placements.append({'zone':zone,'name':name,'asset':assets[id],'x':point.x,'y':base,'z':point.y,'radius':radius,'depth':depth})
   template.free()
 FileAccess.open("res://world/river/rock_landscaping.tscn",FileAccess.WRITE).store_string(text)
 FileAccess.open("res://world/river/rock_landscaping_manifest.json",FileAccess.WRITE).store_string(JSON.stringify(placements,"  "))
 print("LANDSCAPING AUTHORED: ",placements.size()," placements, ",assets.size()," models, four zones")
 world.free();quit()
