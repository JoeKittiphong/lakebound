extends SceneTree
## Offline authoring: saved terrain/collision, editable hierarchy, LOD MultiMeshes and separate stream cells.
const DIR := "res://world/rainforest_lake"
const ASSET := "res://assets/environment/rainforest_lake"
const Batch=preload("res://world/rainforest_lake/foliage_batch.gd")
var definition: RainforestLakeDefinition
var shared: Material
var meshes: Dictionary={}
var placements: Dictionary={}
var distant: Dictionary={}
var shore_distant: Dictionary={}
var shoreline_metrics: Dictionary={}
var rng := RandomNumberGenerator.new()
var world: Node3D
var counts: Dictionary={}
var available: Array[Vector2i]=[]

func _initialize() -> void: call_deferred("build")

func own(node: Node,parent: Node,owner_node: Node) -> void:
 parent.add_child(node)
 node.owner=owner_node

func pack(node: Node,path: String) -> void:
 var scene:=PackedScene.new()
 assert(scene.pack(node)==OK)
 assert(ResourceSaver.save(scene,path)==OK)

func find_meshes(node: Node,t: Transform3D,tool: SurfaceTool,override_material: bool) -> void:
 if node is Node3D:t=t*node.transform
 if node is MeshInstance3D and node.mesh!=null:
  # External old scenes can include alternate LOD meshes: only their closest representation is authored here.
  if node.visibility_range_begin>0 or "impostor" in str(node.name).to_lower():return
  for s in node.mesh.get_surface_count():tool.append_from(node.mesh,s,t)
 for child in node.get_children():find_meshes(child,t,tool,override_material)

func load_mesh(name: String,path: String) -> ArrayMesh:
 var node: Node=load(path).instantiate()
 var tool:=SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 find_meshes(node,Transform3D.IDENTITY,tool,true)
 var mesh:=tool.commit()
 mesh.surface_set_material(0,shared)
 node.free()
 ResourceSaver.save(mesh,DIR.path_join("meshes/"+name+".res"),ResourceSaver.FLAG_CHANGE_PATH)
 mesh.take_over_path(DIR.path_join("meshes/"+name+".res"))
 return mesh

func old_surfaces(node: Node,t: Transform3D,tools: Dictionary) -> void:
 if node is Node3D:t=t*node.transform
 if node is MeshInstance3D and node.mesh!=null:
  if node.visibility_range_begin>0 or "impostor" in str(node.name).to_lower():return
  for s in node.mesh.get_surface_count():
   var mat: Material=node.get_active_material(s)
   var key:=mat.get_instance_id() if mat!=null else 0
   if not tools.has(key):
    var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(mat);tools[key]=tool
   tools[key].append_from(node.mesh,s,t)
 for child in node.get_children():old_surfaces(child,t,tools)

func load_old_mesh(name: String,path: String) -> ArrayMesh:
 var node: Node=load(path).instantiate();var tools: Dictionary={};old_surfaces(node,Transform3D.IDENTITY,tools)
 var result:=ArrayMesh.new()
 for tool in tools.values():tool.commit(result)
 ResourceSaver.save(result,DIR.path_join("meshes/"+name+".res"),ResourceSaver.FLAG_CHANGE_PATH);result.take_over_path(DIR.path_join("meshes/"+name+".res"));node.free();return result

func terrain_mesh(origin: Vector2,material: Material) -> ArrayMesh:
 var arrays: Array=[]
 arrays.resize(Mesh.ARRAY_MAX)
 var v:=PackedVector3Array();var n:=PackedVector3Array();var c:=PackedColorArray();var indices:=PackedInt32Array()
 for z in 11:
  for x in 11:
   var p:=origin+Vector2(x*5,z*5)
   var h:=definition.ground_height(p)
   v.append(Vector3(x*5,h,z*5))
   n.append(Vector3(definition.ground_height(p-Vector2(.5,0))-definition.ground_height(p+Vector2(.5,0)),1.,definition.ground_height(p-Vector2(0,.5))-definition.ground_height(p+Vector2(0,.5))).normalized())
   var d:=definition.signed_water_distance(p)
   var grass:=smoothstep(5,16,d)
   # A continuous dry walking trail follows the bank without blocking plants.
   grass*=1.0-.72*(1.0-smoothstep(1.1,2.7,absf(d-9.0)))
   var soil:=1.0-smoothstep(-9,-3,d)
   if definition.in_cave_area(p):grass=0;soil=.72
   c.append(Color(grass,0,soil))
 for z in 10:
  for x in 10:
   var a:=z*11+x
   indices.append_array(PackedInt32Array([a,a+1,a+11,a+1,a+12,a+11]))
 arrays[Mesh.ARRAY_VERTEX]=v;arrays[Mesh.ARRAY_NORMAL]=n;arrays[Mesh.ARRAY_COLOR]=c;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,material)
 return mesh

func cell_key(p: Vector3) -> Vector2i:
 return Vector2i(clampi(floori((p.x+500)/50),0,19),clampi(floori((p.z+250)/50),0,9))

func add_placement(kind: String,p: Vector2,scale_value: float,water_plant: bool=false) -> void:
 var yaw:=rng.randf()*TAU
 if definition.cave_enabled and definition.cave_bounds.grow(7).has_point(p):return
 if kind not in ["tree_a","tree_b","old_tree","cliff","cliff_pillar"] and access_corridor(p):return
 var y:=definition.ground_height(p)
 if water_plant and kind!="seaweed":y=maxf(y,definition.water_height-.15)
 if kind=="old_lotus":y=definition.water_height-.012
 if kind in ["emergent_lotus","shore_reeds"]:y=maxf(y,definition.water_height-.28)
 var point:=Vector3(p.x,y,p.y)
 var transform:=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale_value),point)
 var key:=cell_key(point)
 if not placements.has(key):placements[key]={}
 if not placements[key].has(kind):placements[key][kind]=[]
 placements[key][kind].append(transform)
 counts[kind]=int(counts.get(kind,0))+1
 if kind in ["rock_flat","rock_boulder","old_lotus","shore_reeds","emergent_lotus"] and absf(definition.signed_water_distance(p))<28:
  if not shore_distant.has(key):shore_distant[key]={}
  if not shore_distant[key].has(kind):shore_distant[key][kind]=[]
  # Sparse persistent silhouettes prevent the waterline becoming empty beyond detail cells.
  if int(counts[kind])%3==0:shore_distant[key][kind].append(transform)
 if kind in ["tree_a","tree_b","old_tree"]:
  var far_kind: String="tree_b_far" if kind=="tree_b" else "tree_a_far"
  if not distant.has(key):distant[key]={}
  if not distant[key].has(far_kind):distant[key][far_kind]=[]
  distant[key][far_kind].append(transform)

func scatter() -> void:
 rng.seed=20261030
 # Jittered grid, deterministic positions, shoreline/trail clearance before placing any tree.
 for z in range(-242,246,8):
  for x in range(-492,496,8):
   var p:=Vector2(x+rng.randf_range(-2.6,2.6),z+rng.randf_range(-2.6,2.6))
   var d:=definition.signed_water_distance(p)
   var arrival_clear:=p.distance_to(definition.spawn_shore)<18
   if d>15 and not arrival_clear and rng.randf()<.68:
    var choice:=rng.randf()
    var kind: String="tree_a" if choice<.56 else "tree_b" if choice<.92 else "old_tree"
    var s:=rng.randf_range(2.0,3.2)
    if kind=="old_tree":s*=.90
    add_placement(kind,p,s)
   if d>1 and not arrival_clear and rng.randf()<.30:
    var kinds: Array[String]=["bush","fern","grass","banana","taro","dark_taro"]
    var kind: String=kinds[rng.randi_range(0,kinds.size()-1)]
    add_placement(kind,p,rng.randf_range(.6,1.25))
   if d>-.8 and d<5 and rng.randf()<.36:
    add_placement("plume_grass" if p.x>150 else "grass",p,rng.randf_range(.7,1.3),true)
   if d>-4 and d<12 and rng.randf()<.12:
    add_placement("rock_flat" if rng.randf()<.6 else "rock_boulder",p,rng.randf_range(1,2.8))
   if d< -4 and d> -18 and rng.randf()<.065:
    add_placement("seaweed",p,rng.randf_range(1.0,2.0),true)
   if d>10 and not arrival_clear and rng.randf()<.035:add_placement("old_log",p,rng.randf_range(.7,1.3))
 # Dense fern/grass margins frame the shore while leaving the walking trail open.
 for z in range(-242,246,4):
  for x in range(-492,496,4):
   var p:=Vector2(x+rng.randf_range(-1.4,1.4),z+rng.randf_range(-1.4,1.4))
   var d:=definition.signed_water_distance(p)
   if d<3 or d>48 or absf(d-9)<3 or p.distance_to(definition.spawn_shore)<18:continue
   if rng.randf()<.46:
    var kinds: Array[String]=["fern","grass","bush","taro","dark_taro"]
    add_placement(kinds[rng.randi_range(0,4)],p,rng.randf_range(.8,1.5))
 dress_shoreline()
 for p in [Vector2(-232,-148),Vector2(270,-125),Vector2(358,65),Vector2(75,139)]:
  add_placement("rock_boulder",p,3.0)

func access_corridor(p: Vector2) -> bool:
 if RainforestLakeDefinition.segment_distance(p,Vector2(-320,148),Vector2(-314,96))<9:return true
 for i in definition.channel_starts.size():
  if RainforestLakeDefinition.segment_distance(p,definition.channel_starts[i],definition.channel_ends[i])<definition.channel_half_width+5:return true
 return false

func dress_shoreline() -> void:
 # Irregular patches, rather than a uniform ring, leave open fishing windows.
 for z in range(-242,246,10):
  for x in range(-492,496,10):
   var p:=Vector2(x+rng.randf_range(-3,3),z+rng.randf_range(-3,3))
   var d:=definition.signed_water_distance(p)
   if d< -27 or d>6 or access_corridor(p):continue
   var patch:=(sin(p.x*.043+p.y*.021)+sin(p.y*.068-p.x*.019))*.25+.5
   if patch<.26 or rng.randf()>.78:continue
   # Partially submerged low-poly rock groups frame coves and island edges.
   if d> -22 and d<3 and rng.randf()<.60:
    for i in rng.randi_range(2,5):
     var q:=p+Vector2(rng.randf_range(-3.5,3.5),rng.randf_range(-3.5,3.5))
     var qd:=definition.signed_water_distance(q)
     if qd>3 or qd< -25 or access_corridor(q):continue
     var size:=rng.randf_range(1.7,3.7)
     add_placement("rock_flat" if i%3 else "rock_boulder",q,size)
   if d> -3 and d<6:
    for i in rng.randi_range(5,10):
     var q:=p+Vector2(rng.randf_range(-4,4),rng.randf_range(-4,4))
     var qd:=definition.signed_water_distance(q)
     if qd>6 or qd< -4 or access_corridor(q):continue
     var types: Array[String]=["taro","dark_taro","grass","bush","fern","plume_grass"]
     add_placement(types[rng.randi_range(0,5)],q,rng.randf_range(1.1,2.1),qd<0)
   var depth:=definition.water_depth_at(p)
   if d< -3 and depth>.12 and depth<1.25:
    for i in rng.randi_range(4,9):
     var q:=p+Vector2(rng.randf_range(-4.5,4.5),rng.randf_range(-4.5,4.5))
     var qdepth:=definition.water_depth_at(q)
     if qdepth<.14 or qdepth>1.4 or access_corridor(q):continue
     var kind: String="old_lotus" if i%4!=0 else "emergent_lotus"
     add_placement(kind,q,rng.randf_range(1.15,2.2),true)
    if rng.randf()<.65:add_placement("shore_reeds",p,rng.randf_range(1.1,1.9),true)
 # Measure actual shelf area against the previous steep-bed formula on a 2 m grid.
 var shallow:=0;var old_shallow:=0;var water_area:=0;var previous_water_area:=0
 for z in range(-248,250,2):
  for x in range(-498,500,2):
   var p:=Vector2(x,z);var d:=definition.signed_water_distance(p)
   if definition.previous_water_distance(p)<0:previous_water_area+=4
   if d>=0:continue
   water_area+=4
   var depth:=definition.water_depth_at(p)
   if depth>=.1 and depth<=1.2:shallow+=4
   var old_depth:=.04+11.5*smoothstep(0,32,-d)
   if old_depth>=.1 and old_depth<=1.2:old_shallow+=4
 shoreline_metrics={"shallow_area_m2":shallow,"previous_shallow_area_m2":old_shallow,"area_multiplier":float(shallow)/maxi(1,old_shallow),"water_area_m2":water_area,"previous_water_area_m2":previous_water_area,"added_water_m2":water_area-previous_water_area}

func multimesh_node(name: String,mesh: Mesh,transforms: Array,center: Vector3,begin: float,end: float) -> MultiMeshInstance3D:
 var ob:=Batch.new();ob.name=name;ob.authored_mesh=mesh
 for i in transforms.size():
  var t: Transform3D=transforms[i]
  t.origin-=center
  ob.authored_transforms.append(t)
  var shade:=.88+float(i%5)*.025
  if name.begins_with("rock_"):shade*=.82
  ob.authored_colors.append(Color(shade,shade,shade,1))
 ob.visibility_range_begin=begin;ob.visibility_range_end=end
 ob.visibility_range_begin_margin=0;ob.visibility_range_end_margin=0
 ob.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if "tree" in name and "Near" in name else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return ob

func build_cells() -> void:
 var far_root:=Node3D.new();far_root.name="DistantForestLOD";own(far_root,world,world)
 for key in placements:
  available.append(key)
  var center:=Vector3(-500+(key.x+.5)*50,0,-250+(key.y+.5)*50)
  var cell:=Node3D.new();cell.name="DetailCell_%02d_%02d"%[key.x,key.y];cell.position=center
  var collision_body:=StaticBody3D.new();collision_body.name="TreeAndRockCollision";own(collision_body,cell,cell)
  for kind in placements[key]:
   var transforms: Array=placements[key][kind]
   var tree: bool=kind in ["tree_a","tree_b","old_tree"]
   var end:=55.0 if tree else 34.0 if kind in ["fern","taro","dark_taro","bush","grass","plume_grass","seaweed"] else 125.0
   var near:=multimesh_node(kind+"_Near",meshes[kind],transforms,center,0,end)
   own(near,cell,cell)
   if tree or kind in ["rock_flat","rock_boulder","rock_red","cliff","cliff_pillar","old_log"]:
    var box:=BoxShape3D.new()
    var offset:=Vector3(0,1.2,0)
    box.size=Vector3(.22,2.4,.22)
    if not tree:
     box.size=meshes[kind].get_aabb().size;offset=meshes[kind].get_aabb().get_center()
    for value in transforms:
     var transform: Transform3D=value
     transform.origin-=center
     transform.origin+=transform.basis*offset
     var shape:=CollisionShape3D.new();shape.name="Solid_%s_%d"%[kind,collision_body.get_child_count()];shape.shape=box;shape.transform=transform;own(shape,collision_body,cell)
   var mid_kind: String=kind+"_mid"
   if meshes.has(mid_kind):
    var mid:=multimesh_node(kind+"_MidLOD",meshes[mid_kind],transforms,center,end,125 if tree else 100)
    own(mid,cell,cell)
   elif tree:
    own(multimesh_node(kind+"_MidLOD",meshes[kind],transforms,center,end,125),cell,cell)
  pack(cell,DIR.path_join("cells/cell_%02d_%02d.scn"%[key.x,key.y]))
  cell.free()
 for key in distant:
  var center:=Vector3(-500+(key.x+.5)*50,0,-250+(key.y+.5)*50)
  var group:=Node3D.new();group.name="FarCell_%02d_%02d"%[key.x,key.y];group.position=center;own(group,far_root,world)
  for kind in distant[key]:own(multimesh_node(kind,meshes[kind],distant[key][kind],center,125,610),group,world)

 for key in shore_distant:
  var center:=Vector3(-500+(key.x+.5)*50,0,-250+(key.y+.5)*50)
  var group:=Node3D.new();group.name="ShoreSilhouette_%02d_%02d"%[key.x,key.y];group.position=center;own(group,far_root,world)
  for kind in shore_distant[key]:
   if not shore_distant[key][kind].is_empty():own(multimesh_node(kind+"_ShoreLOD",meshes[kind],shore_distant[key][kind],center,125,450),group,world)

func build_cliff_wall() -> void:
 var cliff_root:=Node3D.new();cliff_root.name="NorthernCliffWall";own(cliff_root,world,world)
 var body:=StaticBody3D.new();body.name="CliffCollision";own(body,cliff_root,world)
 var transforms: Dictionary={"cliff":[],"cliff_pillar":[],"rock_flat":[]}
 var cliff_rng:=RandomNumberGenerator.new();cliff_rng.seed=30102026
 var previous_z:=-210.0
 for x in range(-430,431,12):
  var shore_z:=-175.0
  for z in range(-247,-125,2):
   if definition.signed_water_distance(Vector2(x,z))< -1:
    shore_z=z;break
  var tangent:=atan2(shore_z-previous_z,12.0);previous_z=shore_z
  if definition.cave_enabled and x>definition.cave_bounds.position.x-11 and x<definition.cave_bounds.end.x+11:continue
  var lower_height:=cliff_rng.randf_range(10,17)
  var upper_height:=cliff_rng.randf_range(8,13)
  var base:=Vector3(x,definition.water_height-.7,shore_z-4)
  add_cliff_piece("cliff",base,Vector3(cliff_rng.randf_range(17,23),lower_height,12),-tangent*.40,body,transforms)
  add_cliff_piece("cliff",base+Vector3(cliff_rng.randf_range(-2,2),lower_height*.76,-3),Vector3(cliff_rng.randf_range(14,19),upper_height,10),cliff_rng.randf_range(-.20,.20)-tangent*.35,body,transforms)
  if x%36==2 or x%36==-34:
   add_cliff_piece("cliff_pillar",base+Vector3(4,0,-2),Vector3(8,cliff_rng.randf_range(24,34),8),cliff_rng.randf_range(-.3,.3),body,transforms)
  if cliff_rng.randf()<.45:
   add_cliff_piece("rock_flat",base+Vector3(3,1,7),Vector3(13,3.5,9),cliff_rng.randf_range(-.4,.4),body,transforms)
 for kind in transforms:
  if transforms[kind].is_empty():continue
  var batch:=multimesh_node(kind+"_CliffWall",meshes[kind],transforms[kind],Vector3.ZERO,0,0)
  batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;own(batch,cliff_root,world)
 world.set_meta("cliff_pieces",transforms["cliff"].size()+transforms["cliff_pillar"].size()+transforms["rock_flat"].size())

func add_cliff_piece(kind: String,foot: Vector3,size: Vector3,yaw: float,body: StaticBody3D,transforms: Dictionary) -> void:
 var bounds: AABB=meshes[kind].get_aabb()
 var basis:=Basis(Vector3.UP,yaw).scaled(size/bounds.size)
 var transform:=Transform3D(basis,foot-basis*Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z))
 transforms[kind].append(transform)
 var shape:=CollisionShape3D.new();shape.name="SolidCliff_%d"%body.get_child_count()
 var box:=BoxShape3D.new();box.size=bounds.size;shape.shape=box
 shape.transform=Transform3D(basis,transform.origin+basis*bounds.get_center());own(shape,body,world)

func cave_roof_height(x: float,z: float) -> float:
 var across:=(x-40)/44
 return 5+13*sqrt(maxf(0,1-across*across))+.5*sin(z*.14+x*.07)

func cave_quad(tool: SurfaceTool,points: Array,uv_origin: Vector2,reverse: bool=false) -> void:
 var order: Array=[0,1,2,0,2,3] if not reverse else [0,2,1,0,3,2]
 var uv: Array[Vector2]=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
 for t in range(0,6,3):
  var a: Vector3=points[order[t]];var b: Vector3=points[order[t+1]];var c: Vector3=points[order[t+2]]
  var normal: Vector3=(c-a).cross(b-a).normalized()
  for j in 3:
   var index: int=order[t+j]
   tool.set_normal(normal);tool.set_uv(uv_origin+Vector2(.005,.005)+uv[index]*.115);tool.add_vertex(points[index])

func build_cave() -> void:
 if not definition.cave_enabled:return
 var cave:=Node3D.new();cave.name="CliffFishingCave";own(cave,world,world)
 var material:=shared.duplicate() as StandardMaterial3D;material.resource_name="Cave_Rock_SharedAtlas";material.albedo_color=Color(.58,.62,.64)
 var native_uv: PackedVector2Array=meshes["cliff"].surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
 var uv_origin:=Vector2(floorf(native_uv[0].x*8),floorf(native_uv[0].y*8))/8
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(material)
 var rect:=definition.cave_bounds
 for z_index in 10:
  var z0:=lerpf(rect.position.y,rect.end.y,z_index/10.0);var z1:=lerpf(rect.position.y,rect.end.y,(z_index+1)/10.0)
  for x_index in 20:
   var x0:=lerpf(rect.position.x,rect.end.x,x_index/20.0);var x1:=lerpf(rect.position.x,rect.end.x,(x_index+1)/20.0)
   var low: Array=[Vector3(x0,cave_roof_height(x0,z0),z0),Vector3(x1,cave_roof_height(x1,z0),z0),Vector3(x1,cave_roof_height(x1,z1),z1),Vector3(x0,cave_roof_height(x0,z1),z1)]
   var high: Array=[]
   for point: Vector3 in low:high.append(Vector3(point.x,28+sin(point.x*.12)*sin(point.z*.13)*1.4,point.z))
   cave_quad(tool,low,uv_origin,true);cave_quad(tool,high,uv_origin)
   if z_index==0:cave_quad(tool,[low[0],low[1],high[1],high[0]],uv_origin,true)
   if z_index==9:cave_quad(tool,[low[3],low[2],high[2],high[3]],uv_origin)
   if x_index==0:cave_quad(tool,[low[0],low[3],high[3],high[0]],uv_origin)
   if x_index==19:cave_quad(tool,[low[1],low[2],high[2],high[1]],uv_origin,true)
 var roof_mesh:=tool.commit()
 assert(roof_mesh.get_faces().size()>0,"Cave vault geometry must not be empty")
 var roof_path:=DIR.path_join("meshes/cave_vault.res");ResourceSaver.save(roof_mesh,roof_path);roof_mesh.take_over_path(roof_path)
 var roof:=MeshInstance3D.new();roof.name="VaultedStoneRoof";roof.mesh=roof_mesh;own(roof,cave,world)
 var roof_body:=StaticBody3D.new();roof_body.name="RoofCollision";own(roof_body,roof,world)
 var roof_shape:=CollisionShape3D.new();roof_shape.shape=roof_mesh.create_trimesh_shape();own(roof_shape,roof_body,world)
 var wall_body:=StaticBody3D.new();wall_body.name="CaveWallCollision";own(wall_body,cave,world)
 var transforms: Dictionary={"cliff":[],"cliff_pillar":[],"rock_flat":[],"rock_boulder":[]}
 var cave_rng:=RandomNumberGenerator.new();cave_rng.seed=10402026
 for side in [-1,1]:
  var x: float=40+side*43
  for z in range(-239,-169,9):
   add_cliff_piece("cliff",Vector3(x,.1,z),Vector3(10,11,13),cave_rng.randf_range(-.12,.12),wall_body,transforms)
   add_cliff_piece("cliff",Vector3(x,9,z),Vector3(11,12,13),cave_rng.randf_range(-.15,.15),wall_body,transforms)
  for z in [-224.,-205.,-186.]:
   add_cliff_piece("rock_boulder",Vector3(40+side*34,.5,z),Vector3(4,2,5),.15*side,wall_body,transforms)
 # Broken rock blocks hide the regular construction edge of the vaulted shell.
 for x in range(-4,85,8):
  var arch_height:=cave_roof_height(x,rect.end.y)
  add_cliff_piece("cliff",Vector3(x,arch_height-.4,rect.end.y+.8),Vector3(13,31-arch_height+cave_rng.randf_range(-1,2),11),cave_rng.randf_range(-.12,.12),wall_body,transforms)
 for x in [-3.,83.]:add_cliff_piece("cliff_pillar",Vector3(x,.05,rect.end.y),Vector3(11,30,13),0,wall_body,transforms)
 for x in range(3,82,12):add_cliff_piece("cliff",Vector3(x,.1,-245),Vector3(15,20,10),0,wall_body,transforms)
 for kind in transforms:
  if transforms[kind].is_empty():continue
  var batch:=multimesh_node(kind+"_CaveWalls",meshes[kind],transforms[kind],Vector3.ZERO,0,0)
  batch.material_override=material;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;own(batch,cave,world)
 var spikes_tool:=SurfaceTool.new();spikes_tool.begin(Mesh.PRIMITIVE_TRIANGLES);spikes_tool.set_material(material)
 for i in 6:
  var a:=Vector3(cos(i*TAU/6)*.7,0,sin(i*TAU/6)*.7)
  var b:=Vector3(cos((i+1)*TAU/6)*.7,0,sin((i+1)*TAU/6)*.7)
  var tip:=Vector3(.15,-2.8,.1)
  var normal: Vector3=(b-a).cross(tip-a).normalized()
  var vertices: Array[Vector3]=[a,tip,b]
  for j in 3:
   spikes_tool.set_normal(normal);spikes_tool.set_uv(uv_origin+Vector2(.005,.005)+Vector2(j*.04,j*.03));spikes_tool.add_vertex(vertices[j])
 var spike_mesh:=spikes_tool.commit()
 var spike_path:=DIR.path_join("meshes/cave_stalactite.res");ResourceSaver.save(spike_mesh,spike_path);spike_mesh.take_over_path(spike_path)
 var spike_transforms: Array=[]
 for x in [12.,26.,54.,68.]:
  for z in [-188.,-204.,-221.,-233.]:
   var scale_value:=cave_rng.randf_range(.7,1.5)
   spike_transforms.append(Transform3D(Basis.from_scale(Vector3.ONE*scale_value),Vector3(x,cave_roof_height(x,z)+.1,z)))
 var spikes:=multimesh_node("CeilingStalactites",spike_mesh,spike_transforms,Vector3.ZERO,0,0);own(spikes,cave,world)
 for setting in [{"name":"MouthBounce","position":Vector3(40,8,-185),"color":Color(.46,.71,.73),"energy":.45},{"name":"WestRockBounce","position":Vector3(17,7,-212),"color":Color(.88,.65,.42),"energy":.55},{"name":"RearRockBounce","position":Vector3(50,8,-231),"color":Color(.65,.67,.60),"energy":.4}]:
  var light:=OmniLight3D.new();light.name=setting.name;light.position=setting.position;light.light_color=setting.color;light.light_energy=setting.energy;light.omni_range=32;light.shadow_enabled=false;own(light,cave,world)
 var markers:=Node3D.new();markers.name="CaveMarkers";own(markers,cave,world)
 for setting in [{"name":"BoatApproach","point":Vector3(40,definition.water_height,-150)},{"name":"BoatMooringWest","point":Vector3(19,definition.water_height,-215)},{"name":"BoatMooringEast","point":Vector3(61,definition.water_height,-215)},{"name":"FishingLedgeWest","point":Vector3(12,.4,-215)},{"name":"FishingLedgeEast","point":Vector3(68,.4,-215)}]:
  var marker:=Marker3D.new();marker.name=setting.name;marker.position=setting.point;own(marker,markers,world)
 world.set_meta("cave_roof_triangles",roof_mesh.get_faces().size()/3)

func add_box(name: String,parent: Node3D,position: Vector3,size: Vector3,material: Material=null) -> Node3D:
 var visual:=MeshInstance3D.new();visual.name=name;visual.position=position
 var mesh:=BoxMesh.new();mesh.size=size;mesh.material=material;visual.mesh=mesh;own(visual,parent,world)
 var body:=StaticBody3D.new();body.name="Collision";own(body,visual,world)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;own(shape,body,world)
 return visual

func facilities() -> void:
 var facilities_root:=Node3D.new();facilities_root.name="ArrivalAndFootbridges";own(facilities_root,world,world)
 var timber:=StandardMaterial3D.new();timber.albedo_color=Color(.30,.18,.075);timber.roughness=.92
 var dock:=Node3D.new();dock.name="Jetty";dock.position=Vector3(-320,.9,132);dock.rotation.y=PI;own(dock,world,world)
 var visual: Node3D=load("res://assets/environment/bridge/wooden_bridge_joined.glb").instantiate()
 visual.name="TimberVisual";visual.position=Vector3(-.00293,-.124693,1.2022675);visual.scale=Vector3(.2575,.18,.625);own(visual,dock,world)
 var body:=StaticBody3D.new();body.name="DeckCollision";own(body,dock,world)
 var shape:=CollisionShape3D.new();shape.name="Deck";shape.position=Vector3(0,-.08,12);var box:=BoxShape3D.new();box.size=Vector3(2.8,.14,24);shape.shape=box;own(shape,body,world)
 var ramp:=add_box("ArrivalRamp",facilities_root,Vector3(-320,.98,136),Vector3(2.8,.16,10),timber);ramp.rotation.x=deg_to_rad(-1.8)
 for i in definition.channel_starts.size():
  var middle:=definition.channel_starts[i].lerp(definition.channel_ends[i],.5)
  var direction: Vector2=(definition.channel_ends[i]-definition.channel_starts[i]).normalized()
  var bridge:=Node3D.new();bridge.name="PoolChannelBridge%d"%i;bridge.position=Vector3(middle.x,4.8,middle.y);bridge.rotation.y=atan2(-direction.y,direction.x);own(bridge,facilities_root,world)
  add_box("Deck",bridge,Vector3.ZERO,Vector3(3.2,.22,39),timber)
  for side in [-1,1]:
   var approach:=add_box("Approach%d"%side,bridge,Vector3(0,-1.6,side*32.5),Vector3(3.2,.20,26),timber);approach.rotation.x=side*deg_to_rad(7.0)
   add_box("Rail%d"%side,bridge,Vector3(side*1.55,.75,0),Vector3(.10,.12,39),timber)
  for z in [-16.,16.]:
   for x in [-1.4,1.4]:add_box("Pier_%s_%s"%[x,z],bridge,Vector3(x,-2.6,z),Vector3(.18,5.2,.18),timber)

func build() -> void:
 definition=load(DIR.path_join("lake_definition.tres"))
 print("AUTHORING: baking irregular shoreline field")
 var field:=definition.bake_shoreline()
 var field_path:=DIR.path_join("shoreline_field.res")
 assert(ResourceSaver.save(field,field_path)==OK);field.take_over_path(field_path)
 definition.bake_fish_habitats()
 assert(ResourceSaver.save(definition,DIR.path_join("lake_definition.tres"))==OK)
 print("AUTHORING: shoreline field saved")
 shared=load(DIR.path_join("vegetation_material.tres"))
 for folder in ["meshes","terrain","cells"]:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR.path_join(folder)))
 var list: PackedStringArray=DirAccess.get_files_at(ASSET)
 for filename in list:
  if filename.ends_with(".glb"):
   var name:=filename.get_basename()
   meshes[name]=load_mesh(name,ASSET.path_join(filename))
 # Reuse the existing broadleaf model/wood in the new atlas pipeline by leaving its own originals intact.
 meshes["old_tree"]=load_old_mesh("old_tree","res://world/river/props/f01_tree_broad_a.tscn")
 meshes["old_log"]=load_old_mesh("old_log","res://world/river/props/d03_fallen_log.tscn")
 meshes["old_lotus"]=load_old_mesh("old_lotus","res://world/river/props/v04_lily_pad_cluster.tscn")
 meshes["emergent_lotus"]=load_old_mesh("emergent_lotus","res://world/river/props/v16_emergent_lotus.tscn")
 meshes["shore_reeds"]=load_old_mesh("shore_reeds","res://world/river/props/v01_reed_clump.tscn")
 world=Pond.new();world.name="RainforestLake";world.definition=definition
 root.add_child(world)
 var terrain_root:=Node3D.new();terrain_root.name="Terrain_1000x500";own(terrain_root,world,world)
 var ground:=ShaderMaterial.new();ground.shader=load(DIR.path_join("terrain.gdshader"));ground.set_shader_parameter("grass_texture",load("res://assets/environment/river/grass.png"));ground.set_shader_parameter("gravel_texture",load("res://assets/environment/river/gravel.png"));ResourceSaver.save(ground,DIR.path_join("terrain_material.tres"),ResourceSaver.FLAG_CHANGE_PATH);ground.take_over_path(DIR.path_join("terrain_material.tres"))
 for z in 10:
  for x in 20:
   var origin:=Vector2(-500+x*50,-250+z*50)
   var mesh:=terrain_mesh(origin,ground)
   var path:=DIR.path_join("terrain/tile_%02d_%02d.res"%[x,z]);ResourceSaver.save(mesh,path,ResourceSaver.FLAG_CHANGE_PATH);mesh.take_over_path(path)
   var node:=MeshInstance3D.new();node.name="Terrain_%02d_%02d"%[x,z];node.position=Vector3(origin.x,0,origin.y);node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;own(node,terrain_root,world)
   var body:=StaticBody3D.new();body.name="GroundCollision";own(body,node,world)
   var collision:=CollisionShape3D.new();collision.shape=mesh.create_trimesh_shape();own(collision,body,world)
 var water:=MeshInstance3D.new();water.name="RiverWater";water.position.y=definition.water_height
 var plane:=PlaneMesh.new();plane.size=Vector2(1000,500);water.mesh=plane;water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var water_material:=ShaderMaterial.new();water_material.shader=load("res://world/water.gdshader")
 var noise:=FastNoiseLite.new();noise.frequency=.045
 var normals:=NoiseTexture2D.new();normals.width=256;normals.height=256;normals.noise=noise;normals.seamless=true;normals.as_normal_map=true
 water_material.set_shader_parameter("cave_water_enabled",definition.cave_enabled)
 water_material.set_shader_parameter("cave_water_rect",Vector4(definition.cave_bounds.position.x,definition.cave_bounds.position.y,definition.cave_bounds.size.x,definition.cave_bounds.size.y))
 water_material.set_shader_parameter("ripple_normal",normals);water_material.set_shader_parameter("shallow_color",Color(.16,.45,.37));water_material.set_shader_parameter("deep_color",Color(.025,.14,.20));water_material.set_shader_parameter("absorption",.23);water_material.set_shader_parameter("color_depth",3.0);water_material.set_shader_parameter("ripple_strength",.15);plane.material=water_material;own(water,world,world)
 var environment:=WorldEnvironment.new();environment.name="RainforestAtmosphere";var env:=Environment.new();env.background_mode=Environment.BG_SKY;env.sky=load("res://world/river/background/river_sky.tres");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.68,.82,.77);env.ambient_light_energy=.65;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.fog_enabled=true;env.fog_light_color=Color(.53,.69,.65);env.fog_density=.0008;env.fog_sky_affect=.12;environment.environment=env;own(environment,world,world)
 var sun:=DirectionalLight3D.new();sun.name="RainforestSun";sun.rotation_degrees=Vector3(-48,-35,0);sun.light_color=Color(1.,.94,.79);sun.light_energy=1.15;sun.shadow_enabled=true;sun.directional_shadow_max_distance=55;sun.directional_shadow_mode=0;own(sun,world,world)
 scatter();build_cells();build_cliff_wall();build_cave();facilities()
 var markers:=Node3D.new();markers.name="GameplayMarkers";own(markers,world,world)
 var spawn:=Marker3D.new();spawn.name="Spawn";spawn.position=Vector3(-324,1.8,143);own(spawn,markers,world)
 var bridge_marker:=Marker3D.new();bridge_marker.name="Bridge";bridge_marker.position=Vector3(-358,4.95,-127);own(bridge_marker,markers,world)
 var shore_marker:=Marker3D.new();shore_marker.name="Ford";shore_marker.position=Vector3(-310,0,122);own(shore_marker,markers,world)
 var stream:=LakeWorldStreamer.new();stream.name="WorldStreaming";stream.available_cells=available;own(stream,world,world)
 # NodePath remains relative to World when this scene is instanced in gameplay.
 stream.set_meta("target_path","../../Player")
 world.set_meta("shoreline_metrics",shoreline_metrics)
 world.set_meta("placement_counts",counts)
 pack(world,DIR.path_join("rainforest_lake.tscn"))
 var overview:=Node3D.new();overview.name="LakeOverview"
 var instance: Node3D=load(DIR.path_join("rainforest_lake.tscn")).instantiate();overview.add_child(instance);instance.owner=overview
 var camera:=Camera3D.new();camera.name="OverviewCamera";camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=1040;camera.position=Vector3(0,700,0);camera.rotation_degrees=Vector3(-90,0,0);camera.far=1200;overview.add_child(camera);camera.owner=overview
 pack(overview,DIR.path_join("lake_overview.tscn"));overview.free()
 var image:=Image.create(1000,500,false,Image.FORMAT_RGB8)
 for y in 500:
  for x in 1000:
   var p:=Vector2(x-500,y-250);var d:=definition.signed_water_distance(p)
   image.set_pixel(x,y,Color(.06,.32,.36).lerp(Color(.20,.57,.51),1-smoothstep(0,7,definition.water_depth_at(p))) if d<0 else Color(.72,.68,.47).lerp(Color(.18,.35,.21),smoothstep(3,20,d)))
 image.save_png("res://features/map/maps/river.png")
 var map:=FishingMapDefinition.new();map.map_id="river";map.bounds=Rect2(-500,-250,1000,500);map.texture=load("res://features/map/maps/river.png");ResourceSaver.save(map,"res://features/map/maps/river.tres")
 var report:={"bounds":[1000,500],"cells":available.size(),"placements":counts,"terrain_triangles":40000,"atlas_size":2048,"seed":20261030,"shoreline":shoreline_metrics,"cliff_pieces":world.get_meta("cliff_pieces",0),"cave_roof_triangles":world.get_meta("cave_roof_triangles",0)}
 var file:=FileAccess.open("res://../exports/rainforest-lake/build-report.json",FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(report,"  "))
 print("LAKE_BUILD_COMPLETE ",JSON.stringify(report))
 world.queue_free()
 quit()
