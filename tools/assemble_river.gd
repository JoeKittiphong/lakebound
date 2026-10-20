extends SceneTree
const OUT = "res://world/river/"
var manifest: Dictionary
var asset_scenes: Dictionary = {}
func _initialize() -> void:
 call_deferred("build")
func own_tree(node: Node, owner_node: Node) -> void:
 for child in node.get_children():
  child.owner = owner_node
  if child.scene_file_path.is_empty():
   own_tree(child, owner_node)
func save_scene(node: Node, path: String) -> void:
 own_tree(node, node)
 var packed := PackedScene.new()
 assert(packed.pack(node) == OK, path)
 assert(ResourceSaver.save(packed, path) == OK, path)
func build() -> void:
 manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/river/river_manifest.json"))
 DirAccess.make_dir_recursive_absolute(OUT + "props")
 var props = load("res://assets/environment/river/river_props.glb").instantiate()
 root.add_child(props)
 var meshes: Dictionary = {}
 for child in props.find_children("*", "MeshInstance3D", true, false):
  meshes[String(child.name).trim_prefix("ASSET_")] = child
 var wood := StandardMaterial3D.new()
 var leaves := StandardMaterial3D.new()
 wood.roughness = 0.95
 leaves.roughness = 0.9
 leaves.metallic_specular = 0.15
 leaves.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 leaves.alpha_scissor_threshold = 0.42
 leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
 leaves.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 for mi in meshes.values():
  for index in mi.mesh.get_surface_count():
   var original: Material = mi.mesh.surface_get_material(index)
   if original is StandardMaterial3D:
    if original.resource_name.contains("Foliage"):
     leaves.albedo_texture = original.albedo_texture
    elif original.resource_name.contains("Wetland"):
     wood.albedo_texture = original.albedo_texture
 assert(wood.albedo_texture != null and leaves.albedo_texture != null, "shared imported textures")
 ResourceSaver.save(wood, OUT + "wood_material.tres")
 ResourceSaver.save(leaves, OUT + "leaf_material.tres")
 wood = load(OUT + "wood_material.tres")
 leaves = load(OUT + "leaf_material.tres")
 for item in manifest.assets:
  var id: String = item.id
  assert(meshes.has(id), "missing imported prop: " + id)
  var original: MeshInstance3D = meshes[id]
  var actor := Node3D.new()
  actor.name = id
  var visual := MeshInstance3D.new()
  visual.name = "Model"
  visual.mesh = original.mesh
  visual.transform = original.global_transform
  visual.position = Vector3.ZERO
  var foliage: bool = String(item.category) in ["trees", "bushes"]
  visual.visibility_range_end = 90.0 if foliage else (85.0 if String(item.category) in ["aquatic", "grass"] else 0.0)
  for index in visual.mesh.get_surface_count():
   var old_mat: Material = visual.mesh.surface_get_material(index)
   visual.set_surface_override_material(index, leaves if old_mat.resource_name.contains("Foliage") else wood)
  actor.add_child(visual)
  if id in ["F01_Tree_Broad_A", "F02_Tree_Broad_B", "F03_Tree_Slender", "F04_Tree_Flooded_Roots"]:
   visual.visibility_range_end = 64.0
   var impostor := MeshInstance3D.new()
   impostor.name = "DistantTree"
   var quad := QuadMesh.new()
   quad.size = Vector2(6.4, 6.4)
   impostor.mesh = quad
   impostor.position.y = 2.6
   impostor.visibility_range_begin = 64.0
   impostor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   var sprite_material := StandardMaterial3D.new()
   sprite_material.albedo_texture = load("res://assets/environment/river/tree_impostors.png")
   sprite_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
   sprite_material.alpha_scissor_threshold = 0.38
   sprite_material.cull_mode = BaseMaterial3D.CULL_DISABLED
   sprite_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
   sprite_material.billboard_keep_scale = true
   sprite_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
   sprite_material.uv1_scale = Vector3(0.25, 1, 1)
   sprite_material.uv1_offset.x = ["F01_Tree_Broad_A", "F02_Tree_Broad_B", "F03_Tree_Slender", "F04_Tree_Flooded_Roots"].find(id) * 0.25
   impostor.material_override = sprite_material
   actor.add_child(impostor)
  if String(item.category) in ["trees", "rocks", "river stones", "deadwood", "dock", "bridge"] and id != "RIV04_Ford_Pebble_Group" and id != "RIV03_Bridge_Trestle":
   var body := StaticBody3D.new()
   body.name = "Collision"
   var shape_node := CollisionShape3D.new()
   shape_node.name = "Shape"
   if String(item.category) == "trees":
    var shape := CylinderShape3D.new()
    shape.radius = 0.24
    shape.height = minf(3.0, visual.get_aabb().size.y * 0.7)
    shape_node.shape = shape
    shape_node.position.y = shape.height * 0.5
   else:
    shape_node.shape = visual.mesh.create_trimesh_shape()
    shape_node.transform = visual.transform
   body.add_child(shape_node)
   actor.add_child(body)
  save_scene(actor, OUT + "props/" + id.to_lower() + ".tscn")
  asset_scenes[id] = load(OUT + "props/" + id.to_lower() + ".tscn")
  actor.free()
 props.free()
 var world := Node3D.new()
 world.name = "RiverWorld"
 world.set_script(load("res://world/pond/pond.gd"))
 world.definition = load(OUT + "river_definition.tres")
 root.add_child(world)
 # Preserve the existing Godot water shader, noise texture and environment.
 var previous = load("res://world/pond/pond.tscn").instantiate()
 var env: WorldEnvironment = previous.get_node("WorldEnvironment").duplicate()
 env.environment = env.environment.duplicate(true)
 env.environment.fog_density = 0.00015
 world.add_child(env)
 var sun: DirectionalLight3D = previous.get_node("Sun").duplicate()
 sun.directional_shadow_max_distance = 75.0
 world.add_child(sun)
 var water: MeshInstance3D = previous.get_node("Lake").duplicate()
 water.name = "RiverWater"
 var plane := PlaneMesh.new()
 plane.size = Vector2(1200, 1200)
 plane.material = water.mesh.surface_get_material(0)
 water.mesh = plane
 water.position = Vector3(0, -0.18, 0)
 world.add_child(water)
 previous.free()
 var ground_material := ShaderMaterial.new()
 ground_material.shader = load(OUT + "river_ground.gdshader")
 ground_material.set_shader_parameter("grass_texture", load("res://assets/environment/river/grass.png"))
 ground_material.set_shader_parameter("gravel_texture", load("res://assets/environment/river/gravel.png"))
 ResourceSaver.save(ground_material, OUT + "ground_material.tres")
 var terrain := Node3D.new()
 terrain.name = "TerrainTiles"
 world.add_child(terrain)
 var imported = load("res://assets/environment/river/river_terrain.glb").instantiate()
 root.add_child(imported)
 for original in imported.find_children("*", "MeshInstance3D", true, false):
  var tile := MeshInstance3D.new()
  tile.name = original.name
  tile.mesh = original.mesh
  tile.transform = original.global_transform
  tile.material_override = ground_material
  tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  terrain.add_child(tile)
  var body := StaticBody3D.new()
  body.name = "GroundCollision"
  var shape := CollisionShape3D.new()
  shape.name = "Shape"
  shape.shape = tile.mesh.create_trimesh_shape()
  body.add_child(shape)
  tile.add_child(body)
 imported.free()
 var categories: Dictionary = {}
 for category in ["bridge", "trees", "bushes", "rocks", "aquatic", "grass", "landmarks", "backdrop", "jetty"]:
  var group := Node3D.new()
  group.name = category.capitalize()
  world.add_child(group)
  categories[category] = group
 for index in manifest.placements.size():
  var item: Dictionary = manifest.placements[index]
  var id: String = item.id
  var category := "landmarks"
  if id.begins_with("F"): category = "trees"
  elif id.begins_with("B"): category = "bushes"
  elif id.begins_with("V03"): category = "grass"
  elif id.begins_with("V"): category = "aquatic"
  elif id.begins_with("RIV0") and id in ["RIV01_Bridge_Section_12m", "RIV02_Bridge_Ramp_8m", "RIV03_Bridge_Trestle"]: category = "bridge"
  elif id.begins_with("RIV06") or id.begins_with("RIV07"): category = "backdrop"
  elif id.begins_with("R"): category = "rocks"
  elif id.begins_with("P"): category = "jetty"
  var prop: Node3D = asset_scenes[id].instantiate()
  prop.name = id + "_%03d" % index
  var p: Array = item.position
  prop.position = Vector3(p[0], p[1], p[2])
  prop.rotation.y = item.yaw
  prop.scale = Vector3.ONE * float(item.scale)
  prop.set_meta("source_asset", id)
  categories[category].add_child(prop)
 var markers := Node3D.new()
 markers.name = "Landmarks"
 # Avoid duplicate name with existing landmarks group.
 markers.name = "GameplayMarkers"
 world.add_child(markers)
 for point in [{"name": "Spawn", "p": manifest.spawn}, {"name": "Bridge", "p": [world.definition.center_at(-116), 1.55, -116]}, {"name": "Ford", "p": [world.definition.center_at(108), -0.52, 108]}]:
  var marker := Marker3D.new()
  marker.name = point.name
  marker.position = Vector3(point.p[0], point.p[1], point.p[2])
  markers.add_child(marker)
 save_scene(world, OUT + "river_world.tscn")
 # An independent overview can be opened without gameplay.
 var overview := Node3D.new()
 overview.name = "RiverOverview"
 var instance = load(OUT + "river_world.tscn").instantiate()
 instance.name = "World"
 overview.add_child(instance)
 var person = load("res://actors/player/player.tscn").instantiate()
 person.name = "HumanScaleReference"
 person.position = Vector3(manifest.spawn[0], manifest.spawn[1], manifest.spawn[2])
 person.process_mode = Node.PROCESS_MODE_DISABLED
 overview.add_child(person)
 var camera := Camera3D.new()
 camera.name = "OverviewCamera"
 overview.add_child(camera)
 root.add_child(overview)
 camera.position = Vector3(0, 165, 230)
 camera.look_at(Vector3(0, -1, -25), Vector3.UP)
 camera.fov = 56
 camera.far = 1000
 camera.current = true
 save_scene(overview, OUT + "river_overview.tscn")
 overview.free()
 world.free()
 print("RIVER WORLD AUTHORED: ", manifest.assets.size(), " source assets, ", manifest.terrain_tiles, " terrain tiles, ", manifest.placements.size(), " prop instances")
 asset_scenes.clear()
 await process_frame
 await process_frame
 quit()


