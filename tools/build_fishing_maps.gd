extends SceneTree
## Offline bake from the same terrain resource and authored jetty transform as gameplay.
func _initialize() -> void:
 call_deferred("build")

func build() -> void:
 DirAccess.make_dir_recursive_absolute("res://features/map/maps")
 for region in RegionCatalog.MAPS:
  var scene: PackedScene = load(region.scene)
  var state := scene.get_state()
  var definition: RiverDefinition
  var world_scene: PackedScene
  for index in state.get_node_count():
   if state.get_node_name(index) == &"World":
    world_scene = state.get_node_instance(index)
   if state.get_node_name(index) == &"PondEcosystem":
    for property in state.get_node_property_count(index):
     if state.get_node_property_name(index, property) == &"definition":
      definition = state.get_node_property_value(index, property)
  if definition == null:
   push_error("Missing definition for " + region.id)
   quit(1)
   return
  var bounds := definition.walking_bounds.merge(definition.water_bounds)
  var jetty := jetty_transform(world_scene)
  var inverse_jetty := jetty.affine_inverse()
  var pixels := Vector2i((bounds.size / maxf(bounds.size.x,bounds.size.y) * 512).round())
  var image := Image.create(pixels.x, pixels.y, false, Image.FORMAT_RGB8)
  for y in pixels.y:
   for x in pixels.x:
    var point := bounds.position + Vector2((x + 0.5)/pixels.x, (y + 0.5)/pixels.y) * bounds.size
    var depth := definition.water_depth_at(point)
    var color := Color("35646c") if depth > 0.06 else Color("84917a")
    if depth > 0.0 and depth < 0.55:
     color = Color("648b86")
    elif depth == 0.0:
     var height := definition.ground_height(point) - definition.surface_height()
     color = Color("84917a").lerp(Color("4c6756"), clampf(height / 9.0, 0, 1))
    if region.id == "river" and definition.on_bridge(Vector3(point.x, 1.55, point.y)):
     color = Color("c9ad7b")
    # Jetty footprint uses the actual authored transform, including rotation.
    var local := inverse_jetty * Vector3(point.x, 0.52, point.y)
    var dock := absf(local.x) < 1.4 and local.z >= 0 and local.z <= 9.56
    if dock:
     color = Color("c9ad7b")
    image.set_pixel(x, y, color)
  var path := "res://features/map/maps/%s" % region.id
  var error := image.save_png(path + ".png")
  if error != OK:
   push_error("Map bake failed: " + str(error))
   quit(1)
   return
  var resource := '[gd_resource type="Resource" script_class="FishingMapDefinition" load_steps=3 format=3]\n[ext_resource type="Script" path="res://features/map/fishing_map_definition.gd" id="script"]\n[ext_resource type="Texture2D" path="%s.png" id="texture"]\n[resource]\nscript = ExtResource("script")\nmap_id = "%s"\nbounds = Rect2(%s, %s, %s, %s)\ntexture = ExtResource("texture")\n' % [path, region.id, bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]
  var file := FileAccess.open(path + ".tres", FileAccess.WRITE)
  file.store_string(resource)
  print("BAKED ", region.id, " ", bounds)
 quit()

func jetty_transform(scene: PackedScene) -> Transform3D:
 var state := scene.get_state()
 for index in state.get_node_count():
  if state.get_node_name(index) != &"Jetty":
   continue
  var result := Transform3D.IDENTITY
  for property in state.get_node_property_count(index):
   var key := state.get_node_property_name(index, property)
   var value: Variant = state.get_node_property_value(index, property)
   if key == &"transform":
    return value
   if key == &"position":
    result.origin = value
   if key == &"rotation_degrees":
    result.basis = Basis.from_euler(value * PI / 180.0)
  return result
 return Transform3D.IDENTITY
