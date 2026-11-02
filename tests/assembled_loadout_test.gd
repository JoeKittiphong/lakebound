extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func expect(value:bool,label:String)->void:
 checks+=1
 if not value:failures+=1;push_error(label)
func run()->void:
 var profile:AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults();profile.save_path="res://../output/equipment-studio-v02/assembled_qa.cfg";profile.grant_trial_equipment()
 var view:EquipmentLoadoutView=load("res://features/economy/showroom/loadout_view.tscn").instantiate()
 root.add_child(view)
 for id in ["brook_702m","cover_702mh","lotus_450m","current_b602"]:
  expect(profile.equip(id),"equip "+id)
  expect(profile.equipped("reel")==null and profile.equipped("line")==null and profile.equipped("bait")==null,"new rod starts with empty attachments")
  if profile.equipped("rod").mount_layout!="fixed":
   var reel:TackleItem=profile.reel_for_rod(profile.equipped("rod"))
   expect(reel!=null and profile.equip(str(reel.id)),"explicitly mount compatible reel")
  expect(profile.equip("nylon"),"explicitly mount line")
  var selected_bait:=false
  for item:TackleItem in TackleCatalog.ITEMS:
   if item.kind in ["bait","lure"] and profile.quantity(str(item.id))>0 and profile.equipment_fit_error(item).is_empty():
    selected_bait=profile.equip(str(item.id));break
  expect(selected_bait,"explicitly mount compatible bait")
  view.set_profile(profile)
  for dimensions in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(2400,1080)]:
   root.size=dimensions
   await create_timer(.2).timeout
   var rod:=view.assembled_rod()
   expect(rod!=null and profile.equipped("rod").id==id,"actual gameplay rod "+id)
   if rod==null:continue
   expect(view.slots.get_node("Reel").model==null,"no separate reel prop")
   expect(view.slots.get_node("Line").model==null,"no separate spool prop")
   if rod.accepts_reel:
    expect(is_instance_valid(rod.held_reel),"mounted reel")
    expect(rod.held_reel.scene_file_path==profile.equipped("reel").model_scene.resource_path,"selected reel")
    expect(rod.ribbon.visible and rod.ribbon.endpoint_error<.0001,"line through guide centers")
    var foot:Node3D=rod.held_reel.get_node("ReelFoot")
    expect(foot.global_position.distance_to(rod.get_node("ReelMount").global_position)<.0001,"foot seated")
   var leader=view.get_node("View/Viewport/Studio/Leader")
   expect(leader.visible and leader.mesh!=null,"leader reaches bait")
   var pixel:=view.camera.unproject_position((rod.tip.global_position+view.get_node("View/Viewport/Studio/LeaderEnd").global_position)*.5)
   expect(view.pick(pixel)==profile.equipped("line"),"tap leader selects line")
   var frame:=Rect2(Vector2.ZERO,Vector2(view.viewport.size)).grow(1)
   for point in [rod.tip.global_position,rod.global_position,view.get_node("View/Viewport/Studio/LeaderEnd").global_position]:
    expect(frame.has_point(view.camera.unproject_position(point)),"assembly framed "+id)
   if DisplayServer.get_name()!="headless" and dimensions==Vector2i(1280,720):
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://../output/equipment-studio-v02/assembled_"+id+".png")
 view.hide();expect(view.viewport.size==Vector2i(2,2),"release hidden assembly")
 print("ASSEMBLED LOADOUT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
