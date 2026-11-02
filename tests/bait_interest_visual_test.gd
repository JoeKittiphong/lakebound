extends SceneTree
const OUT:="res://../output/bait-interest-v01/"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func expect(value:bool,label:String)->void:
 checks+=1
 if not value:failures+=1;push_error(label)
func settle()->void:
 for i in 5:await process_frame
func capture(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+name+".png")
func run()->void:
 root.size=Vector2i(1280,720)
 root.get_node("FishCollection").recording_enabled=false
 var profile:AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults();profile.save_path=OUT+"visual_qa.cfg"
 var scene:Node3D=load("res://features/gameplay/gameplay.tscn").instantiate();scene.economy_enabled=false
 root.add_child(scene);current_scene=scene
 await settle()
 scene.set_process(false)
 scene.get_node("HUD").hide()
 var controller:FishingController=scene.get_node("FishingController")
 var pond:PondEcosystem=scene.get_node("PondEcosystem")
 var player:Node3D=scene.get_node("Player")
 controller.set_physics_process(false);pond.set_physics_process(false);player.set_physics_process(false)
 var effects:Node3D=scene.get_node("FishingEffects");effects.audio_enabled=false;effects.set_process(false)
 var rig:Node3D=scene.get_node("CameraRig");rig.set_process(false);rig.set_physics_process(false)
 var camera:Camera3D=rig.get_node("Camera3D");camera.make_current()
 var point:=pond.constrain_to_water(player.global_position+Vector3(15,1.2,0));point.y=1.2
 var surface:=Vector3(point.x,effects.water_height,point.z)
 camera.global_position=surface+Vector3(0,13,15);camera.look_at(surface)
 var fish:FishState=pond.fish[0]
 fish.species=load("res://data/fish/tilapia.tres");fish.hunger=1;fish.caution=0
 for record in pond.fish:record.position=point+Vector3(100,0,100)
 controller.cast_position=point;controller.cast_bait_id="worm";controller.state=FishingController.State.WAITING
 pond.set_bait(point,&"worm",false,TackleCatalog.item("worm"))
 var ring:Node3D=effects.get_node("BaitInterest")
 for resolution in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(2400,1080)]:
  root.size=resolution
  for phase in ["waiting","interested","committed"]:
   fish.position=point+Vector3(100,0,100) if phase=="waiting" else point+Vector3(2,0,0) if phase=="interested" else point
   fish.state=&"committed" if phase=="committed" else &"approaching"
   effects._process(.016);effects._update_fish_visuals();await settle()
   expect(ring.visible and ring.phase==phase,"rendered circle reflects live AI "+phase)
   expect(is_equal_approx(ring.radius_m,4.5),"rendered radius matches bait")
   var mat:ShaderMaterial=ring.get_node("Ring").material_override
   expect((mat.get_shader_parameter("ring_color") as Color).is_equal_approx(ring.committed_color if phase=="committed" else ring.interested_color if phase=="interested" else ring.waiting_color),"correct phase color")
   await capture("ring_%s_%dx%d"%[phase,resolution.x,resolution.y])
 expect(effects.get_node("LureVisual").visible,"natural bait model is present underwater")
 expect(effects.get_node("BaitLeader").visible,"float rig has a real leader to submerged bait")
 expect(effects.get_node("LureVisual").global_position.is_equal_approx(surface-Vector3(0,point.y,0)),"natural bait uses actual selected depth")
 expect(effects.get_node("BaitLeaderEnd").global_position.is_equal_approx(effects.get_node("LureVisual/LineTie").global_position),"leader ends at model eye")
 var original_rig:=profile.current_rig()
 controller.cast_terminal_rig=original_rig
 profile.data.equipped.bait="minnow"
 effects._process(.016)
 expect(controller.active_bait_item().id==&"worm","cast retains actual bait when inventory selection changes")
 expect(controller.active_terminal_rig()==original_rig and effects.get_node("BaitLeader").visible,"cast retains float rig and leader")
 expect(effects.get_node("LureVisual").item.id==&"worm" and pond.bait_item.id==&"worm","visual and AI keep the same cast bait")
 profile.data.equipped.bait="worm";controller.cast_terminal_rig=null
 root.size=Vector2i(1280,720)
 for id in ["worm","dough","minnow","spinnerbait"]:
  profile.data.equipped.bait=id;controller.cast_bait_id=id
  var item:TackleItem=TackleCatalog.item(id)
  pond.set_bait(point,item.bait_type,item.kind=="lure",item)
  effects._process(.016)
  var bait:Node3D=effects.get_node("LureVisual")
  camera.global_position=bait.global_position+Vector3(.22,.10,.35);camera.look_at(bait.global_position+Vector3(0,-.025,0))
  await settle();await capture("in_water_"+id)
  expect(bait.instance.scene_file_path==item.model_scene.resource_path,"actual game uses catalog model "+id)
 controller.active_fish=fish;controller.state=FishingController.State.FIGHT;effects._process(.016)
 expect(not ring.visible and effects.get_node("LureVisual").visible,"fight hides attraction but retains bait at hooked fish")
 controller.state=FishingController.State.LOST;effects._process(.016)
 expect(not ring.visible and effects.get_node("LureVisual").instance==null,"lost/reset removes attraction and bait model")
 scene.queue_free();await settle()
 print("BAIT INTEREST VISUAL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
