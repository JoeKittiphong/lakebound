extends SceneTree
const RegionRules=preload("res://world/regions/region_definition.gd")
var current_root: Node3D
var rng:=RandomNumberGenerator.new()
func _initialize() -> void:call_deferred("run")
func add(node: Node,parent: Node) -> void:
 parent.add_child(node);node.owner=current_root
func mesh_node(name: String,mesh: Mesh,parent: Node,position: Vector3=Vector3.ZERO) -> MeshInstance3D:
 var node:=MeshInstance3D.new();node.name=name;node.mesh=mesh;node.position=position;add(node,parent);return node
func prop(path: String,parent: Node,position: Vector3,scale_value: float=1.0) -> Node3D:
 var node: Node3D=load(path).instantiate();node.name="Prop%03d"%parent.get_child_count();node.position=position;node.scale=Vector3.ONE*scale_value;node.rotation.y=rng.randf_range(-PI,PI);add(node,parent);return node
func material(color: Color) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.9;return m
func run() -> void:
 var designs: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/regions/region_design.json"))
 var source_fish: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/regions/species_gameplay_manifest.json"))
 var legacy_world: Node3D=load("res://world/river/river_world.tscn").instantiate()
 var water_template: ShaderMaterial=legacy_world.get_node("RiverWater").mesh.material
 var sky: Sky=load("res://world/river/background/river_sky.tres")
 legacy_world.free()
 for design: Dictionary in designs:
  rng.seed=90100+designs.find(design)*997
  var id: String=design.id;var kind: String=design.kind
  var save_id: String="river" if kind=="river" else id
  var folder: String="res://world/regions/"+id
  DirAccess.make_dir_recursive_absolute(folder)
  var definition: RiverDefinition
  var spawn:=Vector3(-69.52561,.45,42);var boat:=Vector3(-64,-.18,35)
  if kind=="river":
   definition=load("res://world/river/river_definition.tres")
  else:
   var rules=RegionRules.new();rules.region_kind=kind;rules.water_height=-.18
   rules.water_bounds=Rect2(-88,-86,176,172);rules.walking_bounds=Rect2(-90,-88,180,176);rules.islands.clear()
   rules.basin_radii=Vector2(64,54);rules.maximum_depth=2.6;rules.shore_transition=14
   match kind:
    "stream":rules.basin_radii=Vector2(36,72);rules.maximum_depth=3.7;rules.shore_transition=8
    "reservoir":rules.basin_radii=Vector2(70,68);rules.maximum_depth=16;rules.shore_transition=22
    "estuary":
     rules.basin_radii=Vector2(58,74);rules.maximum_depth=8;rules.shore_transition=18;rules.islands.assign([Vector4(6,-25,9,16),Vector4(-9,38,7,14)])
    "ocean":rules.basin_radii=Vector2(84,80);rules.maximum_depth=28;rules.shore_transition=50
   var edge:=rules.center_at(20)-rules.half_width_at(20)
   rules.dock_origin=Vector2(edge-4,20);rules.dock_along_x=kind!="ocean"
   if kind=="ocean":rules.dock_origin=Vector2(0,37)
   spawn=Vector3(edge-5.5,0,20);boat=Vector3(edge+7,-.18,23)
   if kind=="ocean":spawn=Vector3(-3,0,39);boat=Vector3(3,-.18,24)
   spawn.y=rules.ground_height(Vector2(spawn.x,spawn.z))+.08
   definition=rules
   ResourceSaver.save(definition,folder+"/definition.tres");definition.take_over_path(folder+"/definition.tres")
   current_root=Node3D.new();current_root.name="World";current_root.set_script(load("res://world/pond/pond.gd"));current_root.definition=definition
   var env:=Environment.new();env.background_mode=Environment.BG_SKY;env.sky=sky;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.73,.84,.87);env.ambient_light_energy=.65;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
   env.fog_enabled=true;env.fog_density=.0018 if kind=="stream" else .0008;env.fog_light_color=Color(.60,.72,.69)
   var environment:=WorldEnvironment.new();environment.name="WorldEnvironment";environment.environment=env;add(environment,current_root)
   var sun:=DirectionalLight3D.new();sun.name="Sun";sun.rotation_degrees=Vector3(-43,-30,0);sun.light_energy=1.25;sun.shadow_enabled=true;sun.directional_shadow_max_distance=55;add(sun,current_root)
   var wm: ShaderMaterial=water_template.duplicate();wm.resource_local_to_scene=true
   var shallow: Color
   var deep: Color
   match kind:
    "marsh":shallow=Color(.22,.39,.22);deep=Color(.07,.19,.10)
    "stream":shallow=Color(.24,.56,.49);deep=Color(.045,.22,.23)
    "reservoir":shallow=Color(.20,.38,.34);deep=Color(.025,.12,.19)
    "estuary":shallow=Color(.32,.38,.20);deep=Color(.10,.22,.17)
    _:shallow=Color(.15,.63,.64);deep=Color(.015,.13,.29)
   wm.set_shader_parameter("shallow_color",shallow);wm.set_shader_parameter("deep_color",deep);wm.set_shader_parameter("color_depth",3.5);wm.set_shader_parameter("absorption",.7)
   var plane:=PlaneMesh.new();plane.size=Vector2(2200,2200);plane.material=wm
   mesh_node("RiverWater",plane,current_root,Vector3(0,-.18,0)).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
   var steps:=112;var span:=208.0
   for z in range(steps+1):
    for x in range(steps+1):
     var p:=Vector2(-span*.5+span*x/steps,-span*.5+span*z/steps);var h: float=rules.ground_height(p)
     vertices.append(Vector3(p.x,h,p.y));normals.append(Vector3(rules.ground_height(p-Vector2(.2,0))-rules.ground_height(p+Vector2(.2,0)),.4,rules.ground_height(p-Vector2(0,.2))-rules.ground_height(p+Vector2(0,.2))).normalized())
     var grass:=smoothstep(.45,1.7,h) if kind!="ocean" else smoothstep(.8,2.0,h)
     colors.append(Color(grass,0,.75 if kind in ["marsh","estuary"] else .2))
   for z in steps:
    for x in steps:
     var a:=z*(steps+1)+x;indices.append_array([a,a+1,a+steps+1,a+1,a+steps+2,a+steps+1])
   var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
   var ground:=ArrayMesh.new();ground.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   var gm:=ShaderMaterial.new();gm.shader=load("res://world/river/river_ground.gdshader");gm.set_shader_parameter("grass_texture",load("res://assets/environment/river/grass.png"));gm.set_shader_parameter("gravel_texture",load("res://assets/environment/river/gravel.png"));ground.surface_set_material(0,gm)
   ResourceSaver.save(ground,folder+"/terrain.res");ground.take_over_path(folder+"/terrain.res")
   var terrain:=mesh_node("Terrain",ground,current_root);var body:=StaticBody3D.new();body.name="GroundCollision";add(body,terrain)
   var shape:=CollisionShape3D.new();shape.shape=ground.create_trimesh_shape();add(shape,body)
   var jetty: Node3D=load("res://world/river/props/wooden_jetty.tscn").instantiate();jetty.name="Jetty";jetty.position=Vector3(rules.dock_origin.x,.52,rules.dock_origin.y);jetty.rotation.y=PI/2 if rules.dock_along_x else PI;add(jetty,current_root)
   # A gentle physical ramp bridges the raised dock to the bank.
   var ramp:=StaticBody3D.new();ramp.name="Approach";ramp.position=Vector3(0,-.08,-1.1);ramp.rotation.x=deg_to_rad(-4);add(ramp,jetty)
   var rampmesh:=BoxMesh.new();rampmesh.size=Vector3(2.8,.14,2.7);rampmesh.material=material(Color(.40,.26,.14));mesh_node("Visual",rampmesh,ramp)
   var ramp_shape:=CollisionShape3D.new();var rs:=BoxShape3D.new();rs.size=rampmesh.size;ramp_shape.shape=rs;add(ramp_shape,ramp)
   var scenery:=Node3D.new();scenery.name="Scenery";add(scenery,current_root)
   var rocks:=Node3D.new();rocks.name="Rocks";add(rocks,scenery)
   var trees:=Node3D.new();trees.name="Trees";add(trees,scenery)
   var plants:=Node3D.new();plants.name="Plants";add(plants,scenery)
   var landmarks:=Node3D.new();landmarks.name="Landmarks";add(landmarks,scenery)
   for i in 76:
    var p:=Vector2(rng.randf_range(-85,85),rng.randf_range(-78,78));var depth: float=rules.water_depth_at(p)
    if p.distance_to(Vector2(spawn.x,spawn.z))<12 or p.distance_to(Vector2(boat.x,boat.z))<10:continue
    var path: String="res://world/river/props/concept_rocks_01_06/rock_%02d.tscn"%(i%6+1)
    if i%9==0:path="res://world/river/props/rock_clusters_20_21/rock_21.tscn"
    if i%7==0:path="res://world/river/props/rock_clusters_20_21/rock_20.tscn"
    var scale_value:=rng.randf_range(.55,1.6)*(1.7 if kind=="stream" else 1.0)
    prop(path,rocks,Vector3(p.x,rules.ground_height(p)-.12,p.y),scale_value)
   for i in (145 if kind in ["stream","estuary"] else 90):
    var p:=Vector2(rng.randf_range(-86,86),rng.randf_range(-78,78));var h: float=rules.ground_height(p)
    if p.distance_to(Vector2(spawn.x,spawn.z))<9:continue
    var depth: float=rules.water_depth_at(p)
    if kind=="reservoir" and depth>.5 and depth<10 and i%2==0:
     prop("res://world/river/props/d02_stump_rooted.tscn",landmarks,Vector3(p.x,h,p.y),rng.randf_range(1,2));continue
    if h>.55:
     var treepath: String="res://features/loading/cinematic/pine.tscn" if kind=="stream" else "res://world/river/props/f04_tree_flooded_roots.tscn" if kind=="estuary" else "res://world/river/props/f01_tree_broad_a.tscn"
     if kind=="stream" and p.y<0:treepath="res://world/river/props/f02_tree_broad_b.tscn"
     if kind=="ocean":
      var palm:=Node3D.new();palm.name="Palm%03d"%i;palm.position=Vector3(p.x,h,p.y);add(palm,trees)
      var trunk:=CylinderMesh.new();trunk.height=5.4;trunk.top_radius=.10;trunk.bottom_radius=.23;trunk.radial_segments=7;trunk.rings=1;trunk.material=material(Color(.36,.25,.14));mesh_node("Trunk",trunk,palm,Vector3(0,2.7,0))
      var fronds:=ArrayMesh.new();var fv:=PackedVector3Array()
      for leaf in 9:
       var angle:=TAU*leaf/9.0;var direction:=Vector3(cos(angle),0,sin(angle));var side:=Vector3(-sin(angle),0,cos(angle))*.45
       var center:=Vector3(0,5.5,0);var middle:=center+direction*1.5+Vector3.UP*.35;var tip:=center+direction*3.4-Vector3.UP*1.1
       fv.append_array([center,middle+side,middle-side,middle+side,tip,middle-side])
      var fa:=[];fa.resize(Mesh.ARRAY_MAX);fa[Mesh.ARRAY_VERTEX]=fv;fronds.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,fa);var fm:=material(Color(.20,.40,.13));fm.cull_mode=BaseMaterial3D.CULL_DISABLED;fronds.surface_set_material(0,fm);mesh_node("Fronds",fronds,palm)
     else:
      var o:=prop(treepath,trees,Vector3(p.x,h,p.y),rng.randf_range(.8,1.5));o.set_meta("habitat",kind)
    elif depth<1.5 and kind!="ocean":
     var plantpath: String="res://world/river/props/v04_lily_pad_cluster.tscn" if kind=="marsh" else "res://world/river/props/v02_cattail_clump.tscn"
     prop(plantpath,plants,Vector3(p.x,-.15 if kind=="marsh" else h,p.y),rng.randf_range(.8,1.7))
   if kind=="marsh":
    for patch in 42:
     var z:=rng.randf_range(-43,43);var x: float=(rules.center_at(z)-rules.half_width_at(z)+rng.randf_range(1.8,5.0))*(1 if patch%2==0 else -1)
     if Vector2(x,z).distance_to(Vector2(boat.x,boat.z))>8:
      prop("res://world/river/props/v16_emergent_lotus.tscn",plants,Vector3(x,-.22,z),rng.randf_range(1.2,2.0))
   if kind=="reservoir":
    for stump in 30:
     var z:=rng.randf_range(-48,48);var x: float=rules.center_at(z)-rules.half_width_at(z)+rng.randf_range(3,14)
     if Vector2(x,z).distance_to(Vector2(boat.x,boat.z))>9:
      var h: float=rules.ground_height(Vector2(x,z))
      prop("res://world/river/props/f05_standing_dead_tree.tscn",landmarks,Vector3(x,h,z),rng.randf_range(1.0,1.8))
   if kind=="estuary":
    for root_tree in 36:
     var z:=rng.randf_range(-65,65);var sign_value: float=1 if root_tree%2==0 else -1
     var x: float=rules.center_at(z)+sign_value*(rules.half_width_at(z)-rng.randf_range(.3,2.3))
     if Vector2(x,z).distance_to(Vector2(boat.x,boat.z))>10:
      prop("res://world/river/props/f04_tree_flooded_roots.tscn",trees,Vector3(x,rules.ground_height(Vector2(x,z)),z),rng.randf_range(.9,1.4))
   if kind=="ocean":
    for reef in 24:
     var p:=Vector2(rng.randf_range(-60,60),rng.randf_range(-10,18));var h: float=rules.ground_height(p)
     var coral:=Node3D.new();coral.name="Coral%02d"%reef;coral.position=Vector3(p.x,h,p.y);add(coral,landmarks)
     for branch in 5:
      var branch_mesh:=CylinderMesh.new();branch_mesh.height=rng.randf_range(.5,1.5);branch_mesh.top_radius=.035;branch_mesh.bottom_radius=.13;branch_mesh.radial_segments=5;branch_mesh.rings=1;branch_mesh.material=material([Color(.65,.30,.26),Color(.69,.53,.28),Color(.37,.42,.60)][reef%3])
      var b:=mesh_node("Branch%d"%branch,branch_mesh,coral,Vector3(rng.randf_range(-.5,.5),branch_mesh.height*.5,rng.randf_range(-.5,.5)));b.rotation.z=rng.randf_range(-.5,.5)
   if kind=="reservoir":
    var wallmesh:=BoxMesh.new();wallmesh.size=Vector3(42,6,3);wallmesh.material=material(Color(.32,.34,.33))
    var dam:=StaticBody3D.new();dam.name="DamWall";dam.position=Vector3(0,2,-69);add(dam,landmarks);mesh_node("Visual",wallmesh,dam)
    var ds:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=wallmesh.size;ds.shape=box;add(ds,dam)
   var markers:=Node3D.new();markers.name="GameplayMarkers";add(markers,current_root)
   var spawn_marker:=Marker3D.new();spawn_marker.name="Spawn";spawn_marker.position=spawn;add(spawn_marker,markers)
   var packed:=PackedScene.new();assert(packed.pack(current_root)==OK);assert(ResourceSaver.save(packed,folder+"/world.tscn")==OK);current_root.free()
  # Complete gameplay scenes expose all existing controls, boat and save systems.
  var source:=FileAccess.get_file_as_string("res://features/gameplay/gameplay.tscn")
  var definition_path: String="res://world/river/river_definition.tres" if kind=="river" else folder+"/definition.tres"
  if kind!="river":source=source.replace("res://world/river/river_world.tscn",folder+"/world.tscn").replace("res://world/river/river_definition.tres",definition_path)
  source=source.replace('[node name="Gameplay" type="Node3D"]','[node name="Gameplay" type="Node3D"]')
  source=source.replace('economy_enabled = true','economy_enabled = true\nmap_id = "'+save_id+'"\nmaximum_fishing_depth = '+str(12.0 if kind=="river" else definition.maximum_depth))
  source=source.replace('position = Vector3(-69.52561, 0.45, 42)','position = Vector3(%f,%f,%f)'%[spawn.x,spawn.y,spawn.z]).replace('position = Vector3(-64.0, -0.18, 35)','position = Vector3(%f,%f,%f)'%[boat.x,boat.y,boat.z])
  if kind=="ocean":source=source.replace("rotation_degrees = Vector3(0, -90, 0)","rotation_degrees = Vector3(0, 0, 0)")
  var fish_resources: Array[String]=[]
  var extra:=""
  var legacy_ids:={}
  if kind=="river":
   for legacy: FishSpecies in FishCatalog.SPECIES:
    var rid:="legacy_fish_"+String(legacy.id)
    extra+='[ext_resource type="Resource" path="%s" id="%s"]\n'%[legacy.resource_path,rid]
    fish_resources.append('ExtResource("'+rid+'")');legacy_ids[String(legacy.id)]=true
  for number in design.fish:
   var e: Dictionary=source_fish[int(number)-1];var rid:="region_fish_"+str(int(number))
   if kind=="river" and legacy_ids.has(e.species_id):continue
   extra+='[ext_resource type="Resource" path="%s" id="%s"]\n'%[e.resource,rid];fish_resources.append('ExtResource("'+rid+'")')
  source=source.replace('[node name="Gameplay"',extra+'\n[node name="Gameplay"')
  source=source.replace('population_limit = 112','population_limit = %d\nspecies = Array[Resource]([%s])'%[112 if kind=="river" else maxi(42,design.fish.size()*3),", ".join(fish_resources)])
  FileAccess.open(design.scene,FileAccess.WRITE).store_string(source)
  print("REGION AUTHORED: ",id," fish=",design.fish.size())
 quit()
