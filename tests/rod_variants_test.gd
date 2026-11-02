extends SceneTree
var checks := 0
var failures := 0
var measurements: Array = []
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + message)
func mesh_count(node: Node) -> int:
 var count := 1 if node is MeshInstance3D else 0
 for child in node.get_children(): count += mesh_count(child)
 return count
func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.save_path = "res://../output/rod-variants-v01/test_profile.cfg"
 expect(profile.grant_trial_equipment(), "trial grant includes variants")
 var ids := {}
 var count := 0
 for item in TackleCatalog.ITEMS:
  expect(not ids.has(item.id), "unique ID " + str(item.id))
  ids[item.id] = true
  if item.kind != "rod" or item.rod_spec == null: continue
  count += 1
  var specification_text: String = preload("res://features/economy/tackle_row.gd").specifications(item)
  expect(not specification_text.contains("%"), "shop formats actual spec numbers " + str(item.id))
  expect(specification_text.contains(item.rod_spec.action), "shop displays the actual action")
  expect(profile.equip(str(item.id)), "owned variant equips " + str(item.id))
  var rod: DetailedFishingRod = item.model_scene.instantiate()
  root.add_child(rod)
  expect(rod.rod_spec == item.rod_spec, "item and visual share authored spec")
  expect(rod.rig != null and rod.rig.get_bone_count() == 13, "single 13-bone skeleton")
  expect(mesh_count(rod.get_node("Model")) == 1, "one exported rod mesh, no other variants")
  rod.set_load(0,0)
  var rest := rod.tip.position
  expect(absf(rest.y - (item.rod_spec.length_m - item.rod_spec.handle_m * .68)) < .025, "real scale %s actual %.5f expected %.5f" % [item.id,rest.y,item.rod_spec.length_m - item.rod_spec.handle_m * .68])
  var handle := rod.rig.find_bone("Handle")
  var handle_rest := rod.rig.get_bone_global_pose(handle)
  var positions := []
  for direction in [Vector3.FORWARD,Vector3.RIGHT,Vector3.LEFT]:
   rod.set_pull_direction(direction)
   for load_amount in [0.0,.25,.6,1.0]:
    rod.set_load(load_amount,0)
    expect(rod.tip.global_position.is_finite(), "finite deformed tip")
    expect(rod.rig.get_bone_global_pose(handle).is_equal_approx(handle_rest), "grip remains rigid")
    if load_amount > 0:
     var displacement := rod.tip.position-rest
     var radial := Vector3(displacement.x,0,displacement.z).normalized()
     expect(radial.dot(direction) > .99, "actual skin follows pull direction")
    positions.append([rod.tip.position.x,rod.tip.position.y,rod.tip.position.z])
  rod.set_load(0,0)
  expect(rod.tip.position.distance_to(rest) < .0001, "release returns precisely to rest")
  expect((rod.held_reel == null) == (item.rod_spec.family == "pole"), "correct fixed-line layout")
  expect(rod.guide_points.size() == rod.config.guides.size(), "all guide anchors retained")
  measurements.append({"id":str(item.id),"positions":positions,"action":item.rod_spec.action})
  rod.free()
 expect(count == 14, "fourteen new specs")
 expect(TackleCatalog.ITEMS.size() == 80, "66 existing and 14 additions")
 expect(ProfileStore.valid(profile.data), "save schema accepts variant IDs")
 var saved := ProfileStore.load_profile(profile.save_path)
 expect(not saved.incompatible and saved.data.equipped == profile.data.equipped, "variants survive save reload")
 # Same power/amplitude, different action: curvature moves toward the tip.
 var centers := []
 for action in ["Slow","Moderate","Moderate-Fast","Fast","Extra-Fast"]:
  var angles := RodSpec.calculate_angles(action,1.45,.22,.4)
  var total := 0.0
  var centroid := 0.0
  for i in 12:
   total += angles[i]
   centroid += angles[i] * float(i)
  expect(absf(total-.58)<.00001,"action retains independent power")
  centers.append(centroid / total)
 for i in range(1,centers.size()): expect(centers[i]>centers[i-1],"faster actions shift flex toward tip")
 var light := RodSpec.calculate_angles("Fast",1.85,.22,.4)
 var heavy := RodSpec.calculate_angles("Fast",1.12,.22,.4)
 expect(light[11]>heavy[11],"higher power resists the same visual load")
 var file := FileAccess.open("res://../output/rod-variants-v01/godot_measurements.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"  "))
 print("ROD VARIANTS: %d checks, %d failures" % [checks,failures])
 quit(0 if failures==0 else 1)
