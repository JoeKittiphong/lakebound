extends SceneTree

const Catalog = preload("res://data/fish/fish_catalog.gd")
const Visual = preload("res://world/pond/fish_visual.tscn")
const Record = preload("res://world/pond/fish_state.gd")
const Pond = preload("res://world/pond/pond_ecosystem.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + message)

func run() -> void:
 var seen := {}
 expect(Catalog.SPECIES.size() == 16, "sixteen species in the shared catalog")
 for definition in Catalog.SPECIES:
  var id: StringName = definition.id
  expect(not seen.has(id), "unique species " + String(id))
  seen[id] = true
  var visual := Visual.instantiate()
  root.add_child(visual)
  var record := Record.new()
  record.species = definition
  record.id = 17
  record.weight = (definition.min_weight + definition.max_weight) * 0.5
  visual.setup(record)
  var model: FishModel = visual.model
  var meshes := model.find_children("*", "MeshInstance3D", true, false)
  expect(meshes.size() == 1, String(id) + " one imported skinned mesh, no placeholder")
  var triangles := 0
  var bounds := AABB()
  for mesh in meshes:
   for surface in mesh.mesh.get_surface_count():
    triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
   var material: BaseMaterial3D = mesh.get_active_material(0)
   expect(material.albedo_texture.get_size() == Vector2(512, 512), String(id) + " painted 512 atlas")
   expect(material.cull_mode == BaseMaterial3D.CULL_DISABLED, String(id) + " two-sided fins")
   expect(mesh.skin != null, String(id) + " imported skin is present")
   bounds = model.global_transform.affine_inverse() * (mesh.global_transform * mesh.get_aabb())
  expect(triangles > 0 and triangles <= 500, String(id) + " complete triangle budget")
  expect(absf(bounds.size.z - 1.0) < 0.02, String(id) + " normalized forward length, no double transform")
  expect(is_equal_approx(visual.scale.z, definition.visual_length_m), String(id) + " weight-relative physical size")
  var player: AnimationPlayer = model.animation_player
  expect(player.get_animation_list().size() == 3, String(id) + " exactly three clips")
  for clip in [&"hover", &"swim", &"fast_swim"]:
   expect(player.has_animation(clip), String(id) + " clip " + String(clip))
   expect(player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, String(id) + " seamless-loop import")
  for pair in [[&"resting", &"hover"], [&"feeding", &"hover"], [&"inspecting", &"hover"], [&"biting", &"hover"], [&"roaming", &"swim"], [&"approaching", &"swim"], [&"hunting", &"fast_swim"], [&"fleeing", &"fast_swim"], [&"hooked", &"fast_swim"], [&"landed", &"hover"]]:
   record.state = pair[0]
   visual._process(0.016)
   expect(model.current_clip == pair[1], String(id) + " state " + String(pair[0]))
  record.state = &"hooked"
  record.stamina = 0.1
  visual._process(0.016)
  expect(model.current_clip == &"hover", String(id) + " fatigued hooked fish slows down")
  var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
  player.play(&"fast_swim", 0.0)
  player.seek(0.10, true)
  player.advance(0.0)
  var tail_index := skeleton.find_bone("Tail")
  var before: Transform3D = skeleton.get_bone_global_pose(tail_index)
  player.seek(0.40, true)
  player.advance(0.0)
  expect(not before.is_equal_approx(skeleton.get_bone_global_pose(tail_index)), String(id) + " imported tail actually animates")
  visual.hide()
  expect(not player.active, String(id) + " pooled hidden fish stops skin animation")
  visual.show()
  expect(player.active, String(id) + " showing pooled fish resumes animation")
  visual.configure_preview()
  expect(not player.active and visual.scale.is_equal_approx(Vector3.ONE), String(id) + " collection uses a frozen unit-sized preview")
  visual.configure_preview(true)
  expect(player.active and model.current_clip == &"hover", String(id) + " result preview animates gently")
  visual.free()

 var pond := Pond.new()
 root.add_child(pond)
 expect(pond.fish.size() == 30 and pond.counts().size() == 16, "population has all sixteen species without increasing pool size")
 for id in seen:
  expect(pond.counts()[id] > 0, "initial population includes " + String(id))
 # Every new species uses the real approach -> inspect -> bite simulation.
 for definition in Catalog.SPECIES:
  var one_species: Array[Resource] = [definition]
  pond.species = one_species
  pond.population_limit = 3
  pond.reset_population(4207)
  var fish: RefCounted = pond.fish[0]
  var bait: Vector3 = Vector3(0, (definition.preferred_depth.x + definition.preferred_depth.y) * 0.5, -16)
  fish.position = bait + Vector3(0.7, 0, 0)
  pond.set_bait(bait, StringName(definition.bait_preferences[0]))
  for tick in 180:
   pond.step(0.15)
   if pond.reserved_fish != null:
    break
  expect(pond.reserved_fish != null, String(definition.id) + " can naturally find compatible bait")
 pond.free()
 await process_frame
 print("FISH MODELS RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
