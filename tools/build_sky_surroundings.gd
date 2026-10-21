extends SceneTree
const OUT := "res://world/river/background/"
func _initialize() -> void: call_deferred("build")
func own_tree(node: Node, owner_node: Node) -> void:
 for child in node.get_children():
  child.owner=owner_node
  own_tree(child,owner_node)
func terrain_height(def: RiverDefinition,p: Vector2) -> float:
 var original := def.ground_height(p)
 var distance_outside := maxf(absf(p.x),absf(p.y))-240.0
 var blend := smoothstep(0.0,280.0,distance_outside)
 var land := smoothstep(8.0,50.0,absf(p.x-def.center_at(p.y))-def.half_width_at(p.y))
 var hills := 13.0+12.0*sin(p.x*.009)*cos(p.y*.007)+5.0*sin(p.y*.019+p.x*.005)
 return original+maxf(0.0,hills)*blend*land
func build() -> void:
 DirAccess.make_dir_recursive_absolute(OUT+"meshes")
 var definition: RiverDefinition=load("res://world/river/river_definition.tres")
 var root_node:=Node3D.new()
 root_node.name="OffMapSurroundings"
 root.add_child(root_node)
 var radii: Array[float]=[1.0,1.45,2.3,4.8]
 var total_triangles:=0
 for side in 4:
  for segment in 4:
   var tool:=SurfaceTool.new()
   tool.begin(Mesh.PRIMITIVE_TRIANGLES)
   var positions: Array[Vector3]=[]
   var colors: Array[Color]=[]
   for r in radii:
    for i in 31:
     var along: float=(-240.0+segment*120.0+i*4.0)*r
     var q:=Vector2(along,-240*r) if side==0 else (Vector2(240*r,along) if side==1 else (Vector2(-along,240*r) if side==2 else Vector2(-240*r,-along)))
     positions.append(Vector3(q.x,terrain_height(definition,q),q.y))
     var d:=absf(q.x-definition.center_at(q.y))-definition.half_width_at(q.y)
     var grass:=smoothstep(1.5,6.0,d)
     colors.append(Color(grass,1.0-grass,0,1))
   for j in 3:
    for i in 30:
     var a:=j*31+i
     for index in [a,a+31,a+1,a+1,a+31,a+32]:
      tool.set_color(colors[index])
      tool.add_vertex(positions[index])
   tool.generate_normals()
   tool.index()
   var mesh:=tool.commit()
   mesh.resource_name="OuterTerrain_%d_%d_180tri" % [side,segment]
   mesh.surface_set_material(0,load("res://world/river/ground_material.tres"))
   var path:=OUT+"meshes/outer_%d_%d.res" % [side,segment]
   assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
   var tile:=MeshInstance3D.new()
   tile.name="OuterTerrain_%d_%d" % [side,segment]
   tile.mesh=load(path)
   tile.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   tile.set_meta("triangles",180)
   root_node.add_child(tile)
   total_triangles+=180
 own_tree(root_node,root_node)
 var packed:=PackedScene.new()
 assert(packed.pack(root_node)==OK)
 assert(ResourceSaver.save(packed,OUT+"off_map_surroundings.tscn")==OK)
 root_node.free()
 print("SURROUNDINGS AUTHORED: 16 compressed mesh patches, ",total_triangles," triangles, no colliders or new ground textures")
 quit()
