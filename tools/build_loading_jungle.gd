extends SceneTree
const OUT = "res://assets/environment/loading_jungle/"
var rng = RandomNumberGenerator.new()
var scene: Node3D
var dressing = Node3D.new()
var grounds: Array[Dictionary] = []
var materials: Dictionary = {}
var meshes: Dictionary = {}
var batches: Dictionary = {}
var count = 0
func _initialize():
	call_deferred("build")
func height_at(x: float, z: float) -> float:
	var best = -3.2
	for g in grounds:
		var faces: PackedVector3Array = g.faces
		for i in range(0, faces.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(Vector3(x,100,z), Vector3.DOWN, faces[i],faces[i+1],faces[i+2])
			if hit != null: best = maxf(best,hit.y)
	return best
func mesh_for(kind: String) -> Mesh:
	if meshes.has(kind): return meshes[kind]
	var source = load("res://assets/environment/rainforest_lake/"+kind+".glb").instantiate()
	var target = source.find_child(kind,true,false)
	assert(target is MeshInstance3D,"Exact intended GLB mesh missing: "+kind)
	var mesh = target.mesh.duplicate()
	for s in mesh.get_surface_count(): mesh.surface_set_material(s, materials.rock if kind.begins_with("rock") else materials.leaf)
	ResourceSaver.save(mesh,OUT+kind+".res")
	meshes[kind] = mesh
	source.free()
	return mesh
func add(kind: String, p: Vector3, scale_value: float, far_limit: float = 110.0, shadow: bool = false):
	var key = kind+"_%d_%d" % [floori(p.x/24),floori(p.z/24)]
	if not batches.has(key):
		var batch = MultiMeshInstance3D.new()
		batch.name = key
		batch.set_script(load("res://world/rainforest_lake/foliage_batch.gd"))
		batch.authored_mesh = mesh_for(kind)
		batch.cast_shadow = 1 if shadow else 0
		batch.visibility_range_end = far_limit
		batch.visibility_range_end_margin = 5
		dressing.add_child(batch)
		batch.owner = dressing
		batches[key] = batch
	var b = batches[key]
	b.authored_transforms.append(Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*scale_value),p))
	b.authored_colors.append(Color(rng.randf_range(.87,1.0),rng.randf_range(.91,1.0),rng.randf_range(.85,.98)))
	count += 1
func scatter(kind: String, n: int, rect: Rect2, lo: float, hi: float, scale_lo: float, scale_hi: float, distance: float, shadow: bool = false):
	var placed = 0
	for attempt in n*50:
		if placed >= n: break
		var x = rng.randf_range(rect.position.x,rect.end.x)
		var z = rng.randf_range(rect.position.y,rect.end.y)
		if x > -7 and x < 3 and z > -14 and z < 11: continue
		var y = height_at(x,z)
		if y < lo or y > hi: continue
		var size = rng.randf_range(scale_lo,scale_hi)
		if kind == "seaweed_mid": size = minf(size,(-.16-y)/1.32)
		if size < .15: continue
		if kind == "lily": y = 0.0
		add(kind,Vector3(x,y-.025,z),size,distance,shadow)
		placed += 1
	print("PLACED ",kind," ",placed)
func build():
	rng.seed = 884127
	scene = load("res://features/loading/cinematic/loading_cinematic.tscn").instantiate()
	for name in ["NearShore","NearGrass","LeftBank","LeftForestFloor","RightIsland","FarBank"]:
		var node = scene.get_node("Scenery/"+name)
		var faces = node.mesh.get_faces()
		for i in faces.size(): faces[i] = node.transform*faces[i]
		grounds.append({"faces":faces})
	var leaf = load("res://world/rainforest_lake/vegetation_material.tres").duplicate()
	ResourceSaver.save(leaf,OUT+"foliage.tres")
	var rock = leaf.duplicate()
	rock.transparency = 0
	rock.cull_mode = 0
	ResourceSaver.save(rock,OUT+"rock.tres")
	materials = {"leaf":leaf,"rock":rock}
	var lily_scene = load("res://world/river/props/v04_lily_pad_cluster.tscn").instantiate()
	var lily_meshes = lily_scene.find_children("*","MeshInstance3D",true,false)
	for node in lily_meshes:
		if node.visibility_range_begin == 0 and node.mesh != null:
			meshes.lily = node.mesh
			break
	assert(meshes.has("lily"))
	dressing.name = "LoadingJungle"
	scatter("tree_a_far",120,Rect2(-86,-74,160,17),.2,8,.8,1.35,220)
	scatter("tree_a_far",32,Rect2(18,-45,30,26),.2,8,1.0,1.8,160)
	scatter("tree_a_far",36,Rect2(-38,-46,19,51),.2,8,1.2,2.0,150)
	scatter("bush",80,Rect2(-86,-68,160,12),.2,8,1.0,1.8,180)
	scatter("bush",150,Rect2(-82,-59,152,9),.05,8,1.2,2.1,180)
	scatter("rock_flat",24,Rect2(-76,-57,140,7),-.1,8,1.2,2.2,180)
	scatter("tree_b_mid",18,Rect2(-29,-32,12,39),.2,8,.9,1.5,85,true)
	scatter("bush",65,Rect2(-23,-32,15,45),.1,8,.45,1.0,65)
	scatter("grass_mid",60,Rect2(-22,-31,15,46),.08,8,.35,.7,55)
	scatter("fern_mid",20,Rect2(-21,-27,13,40),.1,8,.4,.7,50)
	scatter("taro_mid",14,Rect2(-19,-25,12,37),.05,3,.55,.95,60)
	scatter("banana_mid",6,Rect2(-24,-23,9,28),.2,8,.7,1.0,70)
	scatter("bush",20,Rect2(3,7,9,11),.15,8,.4,.7,45)
	scatter("grass_mid",20,Rect2(3,7,9,11),.1,8,.35,.65,40)
	scatter("rock_boulder",16,Rect2(-19,-29,11,40),-.25,2,.7,1.7,90,true)
	scatter("rock_flat",12,Rect2(-17,-25,10,36),-.2,2,.8,1.5,80)
	scatter("seaweed_mid",46,Rect2(-17,-25,29,36),-1.5,-.4,.5,1.0,45)
	scatter("lily",28,Rect2(-16,-24,29,30),-2.3,-.15,.6,1.1,65)
	for i in 12:
		add("lily",Vector3(rng.randf_range(4.5,9),0,rng.randf_range(-9,-1)),rng.randf_range(.6,.9),65)
	var background = MeshInstance3D.new()
	background.name = "DistantRainforestBackdrop"
	var quad = QuadMesh.new()
	quad.size = Vector2(240,30)
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = load(OUT+"distant_forest.png")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = .42
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material = mat
	background.mesh = quad
	background.position = Vector3(-25,12,-90)
	background.cast_shadow = 0
	dressing.add_child(background)
	background.owner = dressing
	var packed = PackedScene.new()
	packed.pack(dressing)
	assert(ResourceSaver.save(packed,"res://features/loading/cinematic/loading_jungle_dressing.tscn") == OK)
	print("JUNGLE AUTHORED: ",count," instances in ",batches.size()," batches")
	lily_scene.free()
	scene.free()
	dressing.free()
	quit()
