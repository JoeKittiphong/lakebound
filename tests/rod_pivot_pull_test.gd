extends SceneTree
var failures := 0
var checks := 0
var measurements: Array = []
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + message)
func run() -> void:
 root.get_node("FishCollection").recording_enabled=false
 var scene = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled=false
 root.add_child(scene)
 current_scene=scene
 for i in 5: await process_frame
 scene.set_process(false)
 scene.player.set_physics_process(false)
 scene.fishing.set_physics_process(false)
 scene.pond.set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled=false
 scene.fishing._change_state(FishingController.State.FIGHT)
 var view: FishingEquipmentView=scene.camera_rig.get_node("FishingCamera3D/EquipmentView")
 view.set_process(false)
 var camera: Camera3D=view.get_parent()
 var seen := {}
 for item in TackleCatalog.ITEMS:
  if item.kind != "rod": continue
  scene.player.equip_rod(item)
  view.sync_equipment()
  var rod := view.rod as DetailedFishingRod
  if seen.has(rod.rod_id): continue
  seen[rod.rod_id]=true
  for joystick in [-1.0,0.0,1.0]:
   for i in 120: view.update_rod_pose(1.0/120,Vector2(joystick,0))
   for fish_side in [-1.0,0.0,1.0]:
    var target: Vector3=camera.global_position-camera.global_basis.z*12+camera.global_basis.x*fish_side*8+Vector3.DOWN*2
    for i in 120:
     rod.set_pull_direction((target-rod.tip.global_position).normalized())
     rod.set_load(0.7,joystick)
    var pivot_error := rod.handle_pivot_world().distance_to(view.handle_anchor.global_position)
    expect(pivot_error<0.00001,"fixed handle: %s stick %.0f fish %.0f" % [rod.rod_id,joystick,fish_side])
    var pull: Vector3=rod.pull_direction
    var shaft := rod.global_basis.y.normalized()
    var desired := (pull-shaft*pull.dot(shaft)).normalized()
    rod.set_load(0,joystick)
    var rest := rod.tip.global_position
    rod.set_load(0.7,joystick)
    var displacement := rod.tip.global_position-rest
    var radial := (displacement-shaft*displacement.dot(shaft)).normalized()
    var bend_dot := radial.dot(desired)
    expect(bend_dot>0.98,"actual bend follows pull: %s stick %.0f fish %.0f dot %.5f" % [rod.rod_id,joystick,fish_side,bend_dot])
    var facing_dot := 1.0
    if not rod.guide_points.is_empty():
     expect(rod.get_node("Model").transform.is_equal_approx(rod._model_rest), "guide side stays fixed to handle under lateral pull")
     expect(rod.get_node("ReelMount").transform.is_equal_approx(rod._mount_rest), "reel stays on its authored side")
     expect(rod.ribbon.endpoint_error<0.00001,"line passes all guide anchors")
    if is_instance_valid(rod.held_reel):
     var relative: Basis = rod.get_node("Model").basis.inverse()*rod.get_node("ReelMount").basis
     expect(relative.is_equal_approx(rod._model_rest.basis.inverse()*rod._mount_rest.basis),"reel and guides roll together")
    measurements.append({"rod":rod.rod_id,"stick":joystick,"fish":fish_side,"pivot_error":pivot_error,"bend_dot":bend_dot,"guide_dot":facing_dot})
 expect(seen.size()==26,"all twelve base models and fourteen variants")
 var file=FileAccess.open("res://../output/rod-pivot-alignment/measurements.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(measurements,"  "))
 scene.queue_free()
 await process_frame
 print("ROD PIVOT / PULL: %d checks, %d failures" % [checks,failures])
 quit(0 if failures==0 else 1)

