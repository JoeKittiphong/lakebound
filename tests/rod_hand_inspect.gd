extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled=false
 root.add_child(scene)
 current_scene=scene
 for frame in 15: await process_frame
 scene.set_process(false)
 var player: AnglerPlayer=scene.get_node("Player")
 player.set_physics_process(false)
 scene.get_node("FishingController").set_physics_process(false)
 scene.get_node("PondEcosystem").set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled=false
 var model:=player.character_model
 var skeleton:=model.skeleton
 print("LEAF REST L ",skeleton.get_bone_rest(skeleton.find_bone("hand_leaf_l")).origin," R ",skeleton.get_bone_rest(skeleton.find_bone("hand_leaf_r")).origin)
 var samples:=[]
 for action in ["Fishing_Reel","Fishing_Catch","Fishing_Cast"]:
  model.set_fishing_state(FishingController.State.WAITING,0,0)
  model.update_motion(0.1,false,0,false)
  model.animation_player.play(action,0)
  for t in [0.0,0.25,0.5,0.75]:
   model.animation_player.seek(model.animation_player.get_animation(action).length*t,true)
   model.animation_player.advance(0)
   skeleton.force_update_all_bone_transforms()
   for f in 2: await process_frame
   var sample:Dictionary={"action":action,"time":t,"grip":str(model.rod_grip.global_position),"grip_scale":str(model.rod_grip.global_basis.get_scale())}
   for bone in ["hand_r","hand_l","index_01_r","index_01_l","middle_01_r","middle_01_l"]:
    var idx:=skeleton.find_bone(bone)
    if idx>=0:
     var pos:=skeleton.global_transform*skeleton.get_bone_global_pose(idx).origin
     sample[bone]=str(pos)
     sample[bone+"_in_grip"]=str(model.rod_grip.to_local(pos))
   samples.append(sample)
 print(JSON.stringify(samples))
 scene.queue_free()
 await process_frame
 quit()
