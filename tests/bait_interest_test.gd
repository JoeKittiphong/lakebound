extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func expect(value:bool,label:String)->void:
 checks+=1
 if not value:failures+=1;push_error(label)
func run()->void:
 var pond:=PondEcosystem.new();pond.population_limit=1;pond.species=[load("res://data/fish/tilapia.tres")]
 root.add_child(pond);pond.set_physics_process(false)
 var fish:FishState=pond.fish[0]
 var point:=pond.constrain_to_water(Vector3(0,1.2,-17))
 point.y=1.2
 fish.species=fish.species.duplicate();fish.hunger=1;fish.caution=0;fish.surface_timer=0
 var worm:TackleItem=TackleCatalog.item("worm")
 pond.set_bait(point,&"worm",false,worm)
 fish.position=point+Vector3(worm.attraction.radius_m+.1,0,0)
 expect(not pond._interested_in_bait(fish),"outside bait circle never attracts fish")
 expect(pond.bait_interest_status().phase=="waiting","outside fish leaves blue circle")
 fish.position=point+Vector3(worm.attraction.radius_m-.1,0,0)
 expect(pond._interested_in_bait(fish),"inside preferred bait radius attracts")
 expect(pond.bait_interest_status().phase=="interested","eligible fish turns circle yellow")
 fish.caution=.9;expect(pond.bait_interest_status().phase=="waiting","cautious fish does not light ring")
 fish.caution=0;fish.hunger=.1;expect(not pond._interested_in_bait(fish),"unhungry fish ignores bait")
 fish.hunger=1;fish.species.bait_preferences=PackedStringArray(["lure"])
 expect(not pond._interested_in_bait(fish),"wrong food preference stays ignored")
 fish.species.bait_preferences=PackedStringArray(["worm"])
 pond.bait_position.y=20;fish.position=pond.bait_position
 expect(not pond._interested_in_bait(fish),"wrong depth stays ignored even at circle center")
 pond.bait_position=point;fish.position=point+Vector3(4.4,0,0);pond.line_visibility=2
 expect(not pond._interested_in_bait(fish),"line visibility can shrink individual detection within circle")
 pond.line_visibility=1;fish.position=point
 for i in 8:pond.step(.15)
 expect(fish.state==&"committed" and pond.reserved_fish==null,"natural bait has a real pre-bite commitment phase")
 expect(pond.bait_interest_status().phase=="committed","committed AI turns circle orange")
 for i in 8:pond.step(.15)
 expect(pond.reserved_fish==fish and fish.state==&"biting","committed fish actually bites")
 pond.cancel_bait();expect(not pond.bait_interest_status().active and fish.state==&"roaming","cancel clears fish and ring")
 pond.set_bait(point,&"worm",false,worm);fish.position=point
 for i in 8:pond.step(.15)
 fish.position=point+Vector3(50,0,0)
 expect(pond.bait_interest_status().phase=="waiting","live positions clear stale commitment indication")
 pond.step(.15);expect(fish.state!=&"committed","out-of-range fish abandons bite")
 fish.species.bait_preferences=PackedStringArray(["lure"]);fish.species.detection_radius=20
 var popper:TackleItem=TackleCatalog.item("popper")
 pond.set_bait(point,&"lure",true,popper);fish.position=point
 for i in 12:pond.step(.15)
 expect(pond.reserved_fish==null and pond.bait_interest_status().phase=="interested","lure followers need player rhythm before commitment")
 pond.register_lure_action(1)
 expect(is_equal_approx(pond.attraction_radius(),popper.attraction.radius_m*1.2),"ring includes same capped lure attraction bonus as AI")
 for i in 3:pond.step(.15)
 expect(pond.bait_interest_status().phase=="committed" and pond.reserved_fish==null,"lure commits before actual bite")
 pond.invalidate_lure_action()
 expect(pond.bait_interest_status().phase=="interested","wrong rhythm immediately cancels committed color")
 pond.register_lure_action(1)
 for i in 5:pond.step(.15)
 expect(pond.reserved_fish==fish,"authorized lure decision leads to bite")
 var visual:Node3D=load("res://features/fishing/lure_visual.tscn").instantiate();root.add_child(visual)
 var count:=0
 for item:TackleItem in TackleCatalog.ITEMS:
  if item.kind not in ["bait","lure"]:continue
  count+=1
  expect(item.attraction!=null and item.attraction.radius_m>0,"editable attraction "+str(item.id))
  visual.set_item(item)
  expect(is_instance_valid(visual.instance) and visual.instance.scene_file_path==item.model_scene.resource_path,"actual catalog 3D used in water "+str(item.id))
  var bounds:AABB=visual._bounds(visual.instance)
  expect(absf(maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))-item.attraction.visual_length_m)<.001,"authored size applied "+str(item.id))
  var ties:Array[Node]=visual.instance.find_children("*LineTie*","Node3D",true,false)
  expect(not ties.is_empty(),"authored line eye present "+str(item.id))
  if not ties.is_empty():expect((ties[0] as Node3D).global_position.distance_to(visual.global_position)<.0001,"line attaches to actual eye "+str(item.id))
 expect(count==25,"all 25 baits and lures integrated")
 visual.release_model();expect(visual.instance==null,"inactive cast releases model")
 visual.queue_free();pond.queue_free();await process_frame
 print("BAIT INTEREST: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
