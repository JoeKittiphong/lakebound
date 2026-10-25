extends SceneTree
var checks:=0
var failures:=0
var report: Array=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",label)
func snapshot(skeleton: Skeleton3D) -> Array:
 var values: Array=[]
 for i in skeleton.get_bone_count():values.append(skeleton.get_bone_pose_rotation(i))
 return values
func run() -> void:
 root.size=Vector2i(1600,1100)
 root.get_node("FishCollection").recording_enabled=false
 var manifest: Array=JSON.parse_string(FileAccess.get_file_as_string("res://world/pond/models/encyclopedia/encyclopedia_manifest.json"))
 expect(manifest.size()==100,"100 encyclopedia entries")
 var unique:={}
 for biome in range(1,8):
  var scene: Node3D=load("res://world/pond/models/encyclopedia/preview_biome_%02d.tscn"%biome).instantiate()
  root.add_child(scene);current_scene=scene
  for frame in 3:await process_frame
  for model: Node3D in scene.get_node("Fish").get_children():
   var number: int=model.get_meta("encyclopedia_number")
   var e: Dictionary=manifest[number-1]
   expect(model.scene_file_path==e.model_scene,"correct asset for "+str(number))
   unique[e.model_scene]=true
   var meshes:=model.find_children("*","MeshInstance3D",true,false)
   expect(meshes.size()==1,"one skinned mesh "+str(number))
   var mesh: MeshInstance3D=meshes[0]
   var tris: int=mesh.mesh.surface_get_array_index_len(0)/3
   expect(tris>0 and tris<=500,"triangle budget "+str(number))
   expect(mesh.mesh.get_surface_count()==1,"one surface "+str(number))
   var material:=mesh.get_active_material(0) as StandardMaterial3D
   expect(material!=null and material.albedo_texture!=null and material.albedo_texture.get_width()==512,"packed 512 atlas "+str(number))
   expect(mesh.skin!=null and mesh.skeleton!=NodePath(),"skin import "+str(number))
   var skeleton: Skeleton3D=mesh.get_node(mesh.skeleton)
   expect(skeleton.get_bone_count()>=6,"deforming skeleton "+str(number))
   var players:=model.find_children("*","AnimationPlayer",true,false)
   expect(players.size()==1,"animation player "+str(number))
   var player: AnimationPlayer=players[0]
   var clips: Array=[]
   for clip in ["hover","swim","fast_swim"]:
    expect(player.has_animation(clip),"animation imported "+str(number)+" "+clip)
    if not player.has_animation(clip):continue
    var animation:=player.get_animation(clip)
    expect(animation.loop_mode==Animation.LOOP_LINEAR,"loop import "+str(number)+" "+clip)
    player.stop();player.speed_scale=1.0;player.play(clip,0);player.advance(0)
    var initial:=snapshot(skeleton)
    player.advance(animation.length*.25)
    var mid:=snapshot(skeleton)
    var motion:=0.0
    for i in initial.size():motion=maxf(motion,initial[i].angle_to(mid[i]))
    expect(motion>.0001,"animation changes bones "+str(number)+" "+clip)
    player.advance(animation.length*.75)
    var end:=snapshot(skeleton)
    var seam:=0.0
    for i in initial.size():seam=maxf(seam,initial[i].angle_to(end[i]))
    expect(seam<.005,"loop seam "+str(number)+" "+clip)
    clips.append({"name":clip,"seconds":animation.length,"motion_radians":motion,"seam_radians":seam})
   model.set_motion(&"roaming");player.advance(.4)
   report.append({"number":number,"id":e.id,"status":e.status,"triangles":tris,"clips":clips})
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("fish_encyclopedia_biome_%02d.png"%biome))
  scene.queue_free();await process_frame;await process_frame
 expect(unique.size()==98,"98 distinct models cover 100 entries")
 FileAccess.open("res://exports/qa-fish-models/encyclopedia_import_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FISH ENCYCLOPEDIA RESULT: ",checks," checks, ",failures," failures; ",report.size()," entries, ",unique.size()," unique model scenes")
 quit(int(failures>0))
