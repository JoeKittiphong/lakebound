extends SceneTree
## Offline authoring only. Saved foliage is visible and editable before Play.
const ASSETS := "res://assets/environment/garden/"
const PREFABS := "res://world/vegetation/garden/"
const SOURCE := "res://../art/environment/garden-12-v01/garden_12_game_source.glb"
const MAPS := [
 {"id":"river", "world":"res://world/river/river_world.tscn", "kind":"river", "patches":92, "palette":[1,1,2,2,3,4,5,6,7,7,8,10,11,12]},
 {"id":"lotus_marsh", "world":"res://world/regions/lotus_marsh/world.tscn", "kind":"marsh", "patches":78, "palette":[1,2,3,5,6,7,7,8,9,10,12]},
 {"id":"forest_stream", "world":"res://world/regions/forest_stream/world.tscn", "kind":"stream", "patches":86, "palette":[1,2,3,4,4,4,5,6,7,10,11]},
 {"id":"wild_reservoir", "world":"res://world/regions/wild_reservoir/world.tscn", "kind":"reservoir", "patches":80, "palette":[1,1,2,3,4,5,6,7,8,9,10,12]},
 {"id":"mangrove_estuary", "world":"res://world/regions/mangrove_estuary/world.tscn", "kind":"estuary", "patches":82, "palette":[1,2,3,5,6,7,7,8,9]},
 {"id":"coral_coast", "world":"res://world/regions/coral_coast/world.tscn", "kind":"ocean", "patches":74, "palette":[1,1,2,3,5,5,6,7,7,8,8,12]},
]
var meshes: Dictionary = {}
var plant_info: Dictionary = {}
var shared_material: StandardMaterial3D
var report := {"maps":[], "plant_assets":[], "total_plants":0}
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
 call_deferred("run")

func fail(message: String) -> void:
 push_error(message)
 quit(1)

func prepare_assets() -> bool:
 DirAccess.make_dir_recursive_absolute(PREFABS)
 shared_material = StandardMaterial3D.new()
 shared_material.resource_name = "Garden shared painted foliage"
 shared_material.albedo_texture = load(ASSETS+"flora_atlas_1024.png")
 if shared_material.albedo_texture == null:
  fail("Garden atlas must be imported first")
  return false
 shared_material.albedo_color = Color(.90,.94,.88,1)
 shared_material.roughness = .9
 shared_material.cull_mode = BaseMaterial3D.CULL_DISABLED
 shared_material.vertex_color_use_as_albedo = true
 ResourceSaver.save(shared_material,ASSETS+"garden_material.tres")
 shared_material.take_over_path(ASSETS+"garden_material.tres")
 var document := GLTFDocument.new()
 var state := GLTFState.new()
 var error := document.append_from_file(ProjectSettings.globalize_path(SOURCE),state)
 if error != OK:
  fail("Cannot load garden Blender export: "+str(error))
  return false
 var imported: Node3D = document.generate_scene(state)
 for visual: MeshInstance3D in imported.find_children("*","MeshInstance3D",true,false):
  var id := int(String(visual.name).left(2))
  if id < 1 or id > 12:
   continue
  var mesh := ArrayMesh.new()
  mesh.resource_name = String(visual.name)
  for surface in visual.mesh.get_surface_count():
   mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,visual.mesh.surface_get_arrays(surface))
   mesh.surface_set_material(surface,shared_material)
  var mesh_path := ASSETS+"plant_%02d.res"%id
  ResourceSaver.save(mesh,mesh_path)
  mesh.take_over_path(mesh_path)
  meshes[id] = mesh
  var box := mesh.get_aabb()
  plant_info[id] = {"name":String(visual.name),"radius":maxf(box.size.x,box.size.z)*.5,"triangles":mesh.get_faces().size()/3}
  var prefab := Node3D.new()
  prefab.name = String(visual.name)
  prefab.set_meta("garden_concept",id)
  var node := MeshInstance3D.new()
  node.name = "Visual"
  node.mesh = mesh
  node.visibility_range_end = 68 if id <= 5 else 46
  prefab.add_child(node)
  node.owner = prefab
  var packed := PackedScene.new()
  packed.pack(prefab)
  ResourceSaver.save(packed,PREFABS+"plant_%02d.tscn"%id)
  prefab.free()
  report.plant_assets.append({"id":id,"triangles":plant_info[id].triangles,"mesh":mesh_path})
 imported.free()
 if meshes.size() != 12:
  fail("Expected all twelve approved garden plants, got "+str(meshes.size()))
  return false
 return true

func bank_point(definition: RiverDefinition,kind: String,wet: bool) -> Vector2:
 var offset := rng.randf_range(-.25,1.7) if wet else rng.randf_range(8.5,21.0)
 if kind in ["river","stream","estuary"]:
  var z := rng.randf_range(-98,92) if kind == "river" else rng.randf_range(-72,72)
  var side := -1.0 if rng.randf() < .5 else 1.0
  return Vector2(definition.center_at(z)+side*(definition.half_width_at(z)+offset),z)
 if kind == "ocean":
  var x := rng.randf_range(-76,76)
  return Vector2(x,32-2*sin(x/27)+rng.randf_range(9,37))
 var angle := rng.randf_range(0,TAU)
 var radii: Vector2 = definition.basin_radii
 var edge := Vector2(cos(angle)*radii.x,sin(angle)*radii.y)
 var normal := Vector2(cos(angle)/radii.x,sin(angle)/radii.y).normalized()
 return edge+normal*offset

func build_map(design: Dictionary,index: int) -> bool:
 rng.seed = 20261026+index*991
 var world: Node3D = load(design.world).instantiate()
 root.add_child(world)
 for frame in 3:
  await physics_frame
 var definition: RiverDefinition = world.definition
 var terrain: Node3D = world.get_node("TerrainTiles" if world.has_node("TerrainTiles") else "Terrain")
 var jetty: Node3D = world.get_node("Jetty")
 var spawn: Vector3 = world.get_node("GameplayMarkers/Spawn").global_position
 var space := world.get_world_3d().direct_space_state
 var placement := Node3D.new()
 placement.name = "GardenDressing"
 placement.set_meta("map_id",design.id)
 placement.set_meta("source_library","garden-12-v01")
 placement.set_meta("authoring_seed",rng.seed)
 var batches: Dictionary = {}
 var counts: Dictionary = {}
 var placed_points: Array[Vector2] = []
 var groups: Dictionary = {}
 for label in ["Shrubs","Grasses","Flowers","Waterside"]:
  var group := Node3D.new()
  group.name = label
  placement.add_child(group)
  group.owner = placement
  groups[label] = group
 var patches: int = design.patches
 var attempts := 0
 var made_patches := 0
 while made_patches < patches and attempts < patches*9:
  attempts += 1
  var wet: bool = design.kind != "ocean" and rng.randf() < .22
  var anchor := bank_point(definition,design.kind,wet)
  # A few visible clusters near the starting bank, outside the clear approach.
  if made_patches < 9:
   var angle := rng.randf_range(0,TAU)
   anchor = Vector2(spawn.x,spawn.z)+Vector2(cos(angle),sin(angle))*rng.randf_range(10,22)
   wet = false
  var main_id: int = int(design.palette[rng.randi_range(0,design.palette.size()-1)])
  if wet:
   main_id = [6,7,8,9][rng.randi_range(0,3)]
  var added := 0
  var members := rng.randi_range(3,6)
  if main_id >= 10:
   members = 3
  for member in members:
   var id := main_id
   if member > 0 and rng.randf() < .30:
    id = 7 if rng.randf() < .65 else 5
   var p := anchor+Vector2(rng.randf_range(-2.2,2.2),rng.randf_range(-2.2,2.2))
   var scale_value := rng.randf_range(.78,1.37)
   if id <= 3:
    scale_value *= 1.12
   var radius: float = plant_info[id].radius*scale_value
   if not definition.walking_bounds.grow(-2.5-radius).has_point(p):
    continue
   if p.distance_to(Vector2(spawn.x,spawn.z)) < 7+radius:
    continue
   if design.kind == "river" and (absf(p.y-definition.bridge_z)<12+radius or absf(p.y-definition.ford_z)<12+radius):
    continue
   var local := jetty.to_local(Vector3(p.x,jetty.global_position.y,p.y))
   if absf(local.x)<3.5+radius and local.z>-5-radius and local.z<12+radius:
    continue
   var ground: float = definition.ground_height(p)
   if ground < definition.water_height+(-.28 if id==9 else .08):
    continue
   # Preserve the open shoreline walking strip between reeds and back-bank shrubs.
   if ground > definition.water_height+.15 and ground < definition.water_height+.92:
    continue
   if id==9 and ground>definition.water_height+.8:
    continue
   var near := false
   for previous in placed_points:
    if p.distance_to(previous)<maxf(.65,radius*.70):
     near = true
     break
   if near:
    continue
   var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,45,p.y),Vector3(p.x,-40,p.y),1)
   var hit := space.intersect_ray(query)
   if hit.is_empty() or not terrain.is_ancestor_of(hit.collider) or hit.normal.y<.88:
    continue
   var yaw := rng.randf_range(-PI,PI)
   var basis := Basis(Vector3.UP,yaw).scaled(Vector3(scale_value*rng.randf_range(.91,1.08),scale_value,scale_value*rng.randf_range(.91,1.08)))
   var transform := Transform3D(basis,Vector3(p.x,hit.position.y-.025,p.y))
   var cell := Vector2i(floori(p.x/28),floori(p.y/28))
   var key := "%02d_%d_%d"%[id,cell.x,cell.y]
   if not batches.has(key):
    batches[key] = {"id":id,"cell":cell,"transforms":[],"colors":[]}
   batches[key].transforms.append(transform)
   var tint := rng.randf_range(.91,1.0)
   batches[key].colors.append(Color(tint,tint,tint*.98,1))
   counts[str(id)] = int(counts.get(str(id),0))+1
   placed_points.append(p)
   added += 1
  if added>0:
   made_patches += 1
 for key: String in batches:
  var batch: Dictionary = batches[key]
  var id: int = batch.id
  var center := Vector3((batch.cell.x+.5)*28,0,(batch.cell.y+.5)*28)
  var node := MultiMeshInstance3D.new()
  node.set_script(load("res://world/rainforest_lake/foliage_batch.gd"))
  node.name = "Plant_"+key.replace("-","n")
  node.authored_mesh = meshes[id]
  var local_transforms: Array[Transform3D] = []
  for authored: Transform3D in batch.transforms:
   authored.origin -= center
   local_transforms.append(authored)
  node.authored_transforms = local_transforms
  node.authored_colors.assign(batch.colors)
  node.position = center
  node.visibility_range_end = 68 if id<=5 else 52 if id==9 else 44
  node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if id<=5 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  node.set_meta("garden_concept",id)
  node.set_meta("source_asset",plant_info[id].name)
  node.set_meta("plant_count",local_transforms.size())
  node.set_meta("footprint_radius",plant_info[id].radius)
  var group: Node3D = groups["Flowers" if id>=10 else "Waterside" if id==9 else "Grasses" if id>=6 else "Shrubs"]
  group.add_child(node)
  node.owner = placement
 placement.set_meta("plant_count",placed_points.size())
 placement.set_meta("render_batch_count",batches.size())
 var path: String = String(design.world).get_base_dir()+"/garden_dressing.tscn"
 var packed := PackedScene.new()
 if packed.pack(placement)!=OK or ResourceSaver.save(packed,path)!=OK:
  fail("Cannot save "+path)
  return false
 placement.free()
 world.free()
 await process_frame
 # Minimal text insertion preserves terrain arrays, UIDs and all existing authored work.
 var text := FileAccess.get_file_as_string(design.world)
 if not text.contains('id="garden_dressing"'):
  var line_end := text.find("\n")
  text = text.insert(line_end+1,'\n[ext_resource type="PackedScene" path="'+path+'" id="garden_dressing"]\n')
 if not text.contains('[node name="GardenDressing"'):
  text += '\n[node name="GardenDressing" parent="." instance=ExtResource("garden_dressing")]\n'
 var file := FileAccess.open(design.world,FileAccess.WRITE)
 file.store_string(text)
 file.close()
 var info := {"id":design.id,"world":design.world,"dressing":path,"plants":placed_points.size(),"patches":made_patches,"batches":batches.size(),"types":counts}
 report.maps.append(info)
 report.total_plants += placed_points.size()
 print("GARDEN AUTHORED ",JSON.stringify(info))
 return placed_points.size()>=120

func run() -> void:
 if DisplayServer.get_name()=="headless":
  fail("Run garden authoring with a GPU renderer: headless rendering cannot serialize MultiMesh transforms.")
  return
 if not prepare_assets():
  return
 for index in MAPS.size():
  if not await build_map(MAPS[index],index):
   fail("Insufficient or invalid garden placement in "+MAPS[index].id)
   return
 DirAccess.make_dir_recursive_absolute("res://docs/art")
 var file := FileAccess.open("res://docs/art/garden_placement_report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 file.close()
 print("GARDEN BUILD RESULT: ",report.total_plants," plants across ",report.maps.size()," maps")
 quit()
