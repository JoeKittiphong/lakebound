extends SceneTree
## Validate the actual saved maps; with a display, also capture in-world foliage.
var checks := 0
var failures := 0
var total_plants := 0
var atlas: Texture2D

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool,label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
 print("PASS: " if ok else "FAIL: ",label)

func run() -> void:
 if DisplayServer.get_name()=="headless":
  push_error("Garden placement QA needs the GPU renderer to read serialized MultiMesh instance transforms.")
  quit(1)
  return
 root.size = Vector2i(1280,800)
 root.get_node("FishCollection").recording_enabled = false
 atlas = load("res://assets/environment/garden/flora_atlas_1024.png")
 expect(atlas!=null and atlas.get_width()==1024 and atlas.get_height()==1024,"shared approved garden atlas imports at 1024")
 var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/garden_placement_report.json"))
 expect(report.maps.size()==RegionCatalog.MAPS.size(),"all six selectable maps have authored garden dressing")
 var all_types := {}
 var captured := 0
 for entry in report.maps:
  var world: Node3D = load(entry.world).instantiate()
  root.add_child(world)
  current_scene = world
  for frame in 4:
   await physics_frame
  var garden: Node3D = world.get_node_or_null("GardenDressing")
  expect(garden!=null and garden.scene_file_path==entry.dressing,"saved editable garden instance in "+entry.id)
  if garden==null:
   world.free()
   continue
  var definition: RiverDefinition = world.definition
  var spawn: Vector3 = world.get_node("GameplayMarkers/Spawn").global_position
  var terrain: Node3D = world.get_node("TerrainTiles" if world.has_node("TerrainTiles") else "Terrain")
  var jetty: Node3D = world.get_node("Jetty")
  var types := {}
  var count := 0
  var floor_ok := true
  var clearance_ok := true
  var habitat_ok := true
  var material_ok := true
  var budget_ok := true
  var focus := spawn
  var nearest := INF
  var meshes := garden.find_children("*","MultiMeshInstance3D",true,false)
  expect(garden.find_children("*","CollisionObject3D",true,false).is_empty(),"ornamental plants never add movement or fishing collision in "+entry.id)
  for batch: MultiMeshInstance3D in meshes:
   var id: int = batch.get_meta("garden_concept")
   all_types[id] = true
   types[id] = true
   var mesh: Mesh = batch.multimesh.mesh
   budget_ok = budget_ok and mesh.get_faces().size()/3<=1800 and batch.visibility_range_end<=70
   var mat: StandardMaterial3D = mesh.surface_get_material(0)
   material_ok = material_ok and mat.cull_mode==BaseMaterial3D.CULL_DISABLED and mat.albedo_texture==atlas and mat.vertex_color_use_as_albedo
   for i in batch.multimesh.instance_count:
    count += 1
    var t := batch.global_transform*batch.multimesh.get_instance_transform(i)
    var p := Vector2(t.origin.x,t.origin.z)
    var radius: float = batch.get_meta("footprint_radius")*t.basis.get_scale().y
    clearance_ok = clearance_ok and p.distance_to(Vector2(spawn.x,spawn.z))>=7+radius-.001
    var local := jetty.to_local(Vector3(p.x,jetty.global_position.y,p.y))
    clearance_ok = clearance_ok and not (absf(local.x)<3.5+radius and local.z>-5-radius and local.z<12+radius)
    if entry.id=="river":
     clearance_ok = clearance_ok and absf(p.y-definition.bridge_z)>=12+radius and absf(p.y-definition.ford_z)>=12+radius
    if entry.id=="coral_coast":
     habitat_ok = habitat_ok and id!=9
    habitat_ok = habitat_ok and definition.ground_height(p)>=definition.water_height+(-.28 if id==9 else .08)
    var query := PhysicsRayQueryParameters3D.create(t.origin+Vector3.UP*8,t.origin-Vector3.UP*2,1)
    var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
    floor_ok = floor_ok and not hit.is_empty() and terrain.is_ancestor_of(hit.get("collider")) and absf(t.origin.y-float(hit.get("position",Vector3.ZERO).y))<.09
    var distance := p.distance_to(Vector2(spawn.x,spawn.z))
    if id<=3 and distance<nearest:
     nearest = distance
     focus = t.origin+Vector3.UP*.45
  expect(count==entry.plants and count>=120,"authored population matches report in "+entry.id+": "+str(count))
  expect(types.size()>=7,"varied approved plants in "+entry.id+": "+str(types.size())+" types")
  expect(floor_ok,"plant bases sit on real terrain, away from rock tops in "+entry.id)
  expect(clearance_ok,"spawn, dock, bridge and ford approaches remain clear in "+entry.id)
  expect(habitat_ok,"dry plants stay on land; coast excludes freshwater cattails in "+entry.id)
  expect(material_ok,"approved shared texture and two-sided foliage in "+entry.id)
  expect(budget_ok,"bounded visibility and mesh complexity in "+entry.id)
  total_plants += count
  if DisplayServer.get_name()!="headless":
   var camera := Camera3D.new()
   camera.far = 350
   camera.fov = 54
   world.add_child(camera)
   camera.global_position = focus+Vector3(5,3.1,7)
   camera.look_at(focus)
   camera.make_current()
   for frame in 12:
    await process_frame
   await RenderingServer.frame_post_draw
   var directory := OS.get_environment("LAKEBOUND_QA_DIR")
   if directory.is_empty():
    directory = "res://exports/qa-garden/screenshots"
   DirAccess.make_dir_recursive_absolute(directory)
   root.get_texture().get_image().save_png(directory.path_join("garden_"+entry.id+".png"))
   captured += 1
  world.queue_free()
  for frame in 3:
   await process_frame
 expect(all_types.size()==12,"all twelve approved plant designs used across the maps")
 expect(total_plants==report.total_plants,"all placed plants accounted for")
 # Verify the real selectable gameplay scenes resolve to the same dressed worlds.
 for entry in RegionCatalog.MAPS:
  var game: Node3D = load(entry.scene).instantiate()
  var world: Node3D = game.get_node("World")
  expect(world.has_node("GardenDressing") or world.definition is RainforestLakeDefinition,"selectable map includes its garden or rainforest vegetation in "+entry.id)
  game.free()
 print("GARDEN DRESSING RESULT: ",checks," checks, ",failures," failures, ",total_plants," plants, ",captured," rendered maps")
 quit(int(failures>0))

