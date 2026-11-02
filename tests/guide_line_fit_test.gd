extends SceneTree
var checks := 0
var failures := 0
var samples: Array = []
var nearest_info: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + message)
func clearance(rod: DetailedFishingRod, anchors: PackedVector3Array) -> float:
 var centers := PackedVector3Array()
 for point in rod.config.blank_samples: centers.append(rod.skin_point(point))
 var minimum := INF
 for i in range(anchors.size()-1):
  for j in 17:
   var point := anchors[i].lerp(anchors[i+1],float(j)/16.0)
   for k in range(centers.size()-1):
    var nearest := Geometry3D.get_closest_point_to_segment(point,centers[k],centers[k+1])
    var radius := maxf(rod.config.blank_samples[k].radius,rod.config.blank_samples[k+1].radius)
    var gap := point.distance_to(nearest)-radius
    if gap < minimum:
     minimum = gap
     nearest_info = {"span":i,"blank_segment":k,"line_t":float(j)/16.0}
 return minimum
func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var camera := Camera3D.new()
 root.add_child(camera);camera.position=Vector3(1,1,3);camera.current=true
 var seen := {}
 for item in TackleCatalog.ITEMS:
  if item.kind != "rod": continue
  var rod: DetailedFishingRod = item.model_scene.instantiate()
  root.add_child(rod)
  expect(item.mount_layout == rod.mount_layout, "item/visual agree on mount layout " + str(item.id))
  if seen.has(rod.rod_id):rod.free();continue
  seen[rod.rod_id]=true
  expect(rod.mount_layout=="fixed" or (rod.held_reel!=null and EquipmentFit.accepts(rod.mount_layout,rod.held_reel.mount_family)),"compatible default reel " + rod.rod_id)
  rod.set_load(0,0)
  expect(absf(rod.tip.position.y-(float(rod.config.length)-float(rod.config.grip_x)))<.025,"neutral shaft points along authored +Y at real scale")
  if not rod.guide_points.is_empty():
   var expected_sign := 1.0 if rod.config.layout=="casting" else -1.0
   expect(rod.to_local(rod.guide_points[0]).z*expected_sign>0,"guides sit on their declared upper/lower side")
  for reel in TackleCatalog.ITEMS:
   if reel.kind!="reel":continue
   var old := rod._held_scene
   rod.set_held_reel(reel.model_scene)
   var accepted := EquipmentFit.accepts(rod.mount_layout,reel.reel_family)
   expect(rod._held_scene == (reel.model_scene if accepted else old),"reject incompatible swap before removing reel")
   if not accepted:continue
   expect(rod.held_reel.get_node("ReelFoot").global_position.distance_to(rod.get_node("ReelMount").global_position)<.00001,"foot contact aligns exactly")
   expect(rod.held_reel.config.foot_length <= float(rod.config.seat_length)+.0001,"foot fits actual reel-seat length")
  if rod.mount_layout=="fixed":
   expect(rod.guide_points.is_empty() and rod.held_reel==null,"fixed-line rods have no guide train or reel")
   rod.free();continue
  for direction in [Vector3.FORWARD,Vector3.RIGHT,Vector3.LEFT,Vector3.BACK]:
   for load_amount in [0.0,.35,.7,1.0]:
    rod.set_pull_direction(direction);rod.set_load(load_amount,0)
    expect(rod.get_node("Model").transform.is_equal_approx(rod._model_rest),"guide side never auto-flips")
    expect(rod.get_node("ReelMount").transform.is_equal_approx(rod._mount_rest),"mount never auto-flips")
    expect(rod.ribbon.endpoint_error<.00001,"line goes through every guide center")
    for i in rod.guide_points.size():
     var frame := rod.guide_frame(rod.config.guides[i])
     expect(frame.origin.distance_to(rod.guide_points[i])<.00001,"guide-frame/line anchor coincide")
     expect(frame.basis.x.length()*float(rod.config.guides[i].hole_radius_uv)>rod.ribbon.maximum_width*.5,"rendered line fits aperture width")
    var gap := clearance(rod,rod.ribbon.control_points)
    expect(gap>rod.ribbon.maximum_width*.5+.00005,"visible line edges clear blank %s load %.2f pull %s gap %.6f detail %s" % [rod.rod_id,load_amount,direction,gap,nearest_info])
    samples.append({"rod":rod.rod_id,"load":load_amount,"pull":direction,"clearance_m":gap,"reel":rod.held_reel.reel_id})
  rod.free()
 expect(seen.size()==26,"all 26 rod models covered")
 var file := FileAccess.open("res://../output/guide-line-fit-v01/line_clearance.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"  "))
 print("GUIDE LINE FIT: %d checks, %d failures" % [checks,failures])
 quit(0 if failures==0 else 1)
