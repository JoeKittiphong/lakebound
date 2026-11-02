extends SceneTree
var failures = 0
func check(ok: bool, label: String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures += 1
func _initialize():
	call_deferred("run")
func run():
	var scene = load("res://features/loading/cinematic/loading_jungle_dressing.tscn").instantiate()
	root.add_child(scene)
	var total = 0
	var underwater = 0
	var trees = 0
	var batch_count = 0
	for batch in scene.get_children():
		if not batch is MultiMeshInstance3D: continue
		batch_count += 1
		check(batch.multimesh != null and batch.multimesh.instance_count == batch.authored_transforms.size(),str(batch.name)+" authored instances survive reload")
		var is_rock = str(batch.name).begins_with("rock")
		var is_lily = str(batch.name).begins_with("lily")
		for s in batch.authored_mesh.get_surface_count():
			var m = batch.authored_mesh.surface_get_material(s)
			check(m.transparency == (0 if is_rock or is_lily else 2),str(batch.name)+" opaque or alpha scissor, no alpha blending")
		check(batch.visibility_range_end > 0,str(batch.name)+" finite distance culling")
		if str(batch.name).begins_with("tree_a_far"):
			check(batch.cast_shadow == 0,"far trees do not render shadow passes")
		for t in batch.authored_transforms:
			total += 1
			check(t.origin.is_finite(),"finite transform")
			if str(batch.name).begins_with("tree"): trees += 1
			if str(batch.name).begins_with("seaweed"):
				underwater += 1
				check(t.origin.y+batch.authored_mesh.get_aabb().end.y*t.basis.get_scale().y < 0,"seaweed stays below water surface")
	var backdrop = scene.get_node("DistantRainforestBackdrop")
	check(backdrop.cast_shadow == 0 and backdrop.mesh.material.transparency == 2,"distant image uses scissor without shadows")
	check(trees >= 200 and total >= 700,"dense rainforest composition")
	check(underwater >= 30,"submerged shoreline vegetation present")
	print("JUNGLE RESULT: ",total," instances, ",trees," trees, ",batch_count," authored batches; ",failures," failures")
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
