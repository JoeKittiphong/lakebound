extends SceneTree
var checks:=0
var failures:=0
var output:="res://../output/carry-shop-3d-v01"
func _initialize()->void:call_deferred("run")
func expect(ok:bool,message:String)->void:
 checks+=1
 if not ok:
  failures+=1
  push_error("FAIL: "+message)
func frames(count:int=5)->void:
 for i in count:await process_frame
func capture(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await frames(8);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/"+name+".png")
func loaded(rows:Node)->int:
 var count:=0
 for row in rows.get_children():
  if is_instance_valid(row.get_node("Content/Preview").instance):count+=1
 return count
func run()->void:
 root.size=Vector2i(1280,720)
 root.get_node("FishCollection").recording_enabled=false
 var profile:AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults();profile.save_path=output+"/test_profile.cfg"
 profile.grant_trial_equipment()
 var scene=load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene);current_scene=scene
 await frames(15)
 scene.player.set_physics_process(false);scene.fishing.set_physics_process(false);scene.pond.set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled=false
 scene.hud.get_node("SafeArea/FirstCatch").active=false;scene.hud.get_node("SafeArea/FirstCatch").hide()
 var model:AnglerModel=scene.player.character_model
 var carry_camera:=Camera3D.new()
 root.add_child(carry_camera)
 carry_camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 carry_camera.size=4.4
 for id in ["brook_702m","cover_702mh","lotus_540mh","current_b604"]:
  profile.equip(id);scene.fishing.refresh_equipment()
  model.first_person=false;model.set_fishing_state(FishingController.State.READY,0,0)
  model.update_motion(.02,true,3.8,false)
  expect(model.carrying and model.rod_mesh.visible,"selected rod is visible while walking "+id)
  expect(model.animation_player.current_animation=="carry/Walk","walk layers a fixed right arm over the original gait")
  expect(not model.left_hand_ik.is_running(),"left hand stays free while walking")
  expect(model.rod_mesh.scene_file_path==TackleCatalog.item(id).model_scene.resource_path,"walk carries the selected model")
  model.set_rod_load(.9,.8)
  expect(is_zero_approx(model.rod_mesh.load_amount),"carrying relaxes any leftover fishing load")
  for phase in [0.0,.25,.5,.75]:
   model.animation_player.seek(model.animation_player.current_animation_length*phase,true)
   model.animation_player.advance(0)
   await frames(2)
   var palm:=model.skeleton.global_transform*model.skeleton.get_bone_global_pose(model.skeleton.find_bone("hand_r")).origin
   expect(palm.distance_to(model.rod_mesh.get_node("PrimaryGrip").global_position)<.085,"right palm stays on the grip through the walk cycle")
   expect(model.rod_mesh.tip.global_position.y>model.rod_grip.global_position.y,"carried tip points up instead of into the ground")
  if id in ["brook_702m","cover_702mh"]:
   carry_camera.global_position=model.global_position+Vector3(3,2.4,4.5)
   carry_camera.look_at(model.global_position+Vector3.UP*1.5)
   carry_camera.current=true
   await capture("walking_"+id)
  model.update_motion(.02,false,0,false)
  expect(model.carrying and model.animation_player.current_animation=="carry/Idle_A","stopping keeps the selected rod in hand")
 model.update_motion(.02,true,6.2,false,false,false,true)
 expect(model.carrying and model.animation_player.current_animation=="carry/Sprint","running retains one-handed carry")
 model.update_motion(.02,true,2,false,false,true)
 expect(not model.rod_mesh.visible,"swimming hides carried rod")
 model.driving=true;model.update_motion(.02,false,0,false)
 expect(not model.rod_mesh.visible,"boat steering keeps hands available")
 model.driving=false;model.update_motion(.02,false,0,false)
 carry_camera.queue_free()
 var shop:Control=scene.hud.get_node("TacklePanel")
 shop.open_category(2);await create_timer(.25).timeout
 var shelf:ShopShelfBrowser=shop.get_node("Shop/%Shelf")
 expect(shelf.items.size()==29,"all rod products remain in the showroom")
 expect(shelf.slots().filter(func(slot:ShopShelfSlot):return slot.item!=null).size()==shelf.page_size,"one shelf holds the rods that fit the viewport")
 var inspector:Control=shop.get_node("Shop/%EquipmentInspector")
 inspector.open_item(TackleCatalog.item("brook_702m"));await create_timer(.25).timeout
 var preview:EquipmentModelPreview=inspector.get_node("%Preview")
 expect(is_instance_valid(preview.instance),"selected shelf rod opens actual geometry")
 var zoom:float=preview.camera.size;preview._set_zoom(.5)
 expect(preview.camera.size<zoom,"inspector still zooms")
 var pan:Vector3=preview.pivot.position;preview.pan_view(Vector2(25,10))
 expect(preview.pivot.position!=pan,"inspector pans")
 await capture("rod_inspector")
 inspector.close()
 shop.open_category(3);await create_timer(.25).timeout
 expect(shelf.items.size()==12,"all reels live in the display shelf zone")
 await capture("shop_reels_3d")
 for dimensions in [Vector2i(1024,768),Vector2i(2400,1080)]:
  root.size=dimensions;await create_timer(.25).timeout
  expect(root.get_visible_rect().encloses(shelf.get_global_rect()),"shelf fits resized viewport")
 shop.close();await frames(3)
 expect(shelf.slots().all(func(slot:ShopShelfSlot):return slot.item==null),"closed shop releases shelf products")
 expect(shelf.viewport.size==Vector2i(2,2),"closed shelf shrinks render target")
 scene.queue_free();await process_frame
 print("CARRY / SHOP 3D: %d checks, %d failures" % [checks,failures])
 quit(0 if failures==0 else 1)
