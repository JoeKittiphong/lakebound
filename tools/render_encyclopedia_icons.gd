extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var viewport:=SubViewport.new();viewport.size=Vector2i(256,160);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage:=Node3D.new();viewport.add_child(stage)
 var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_CLEAR_COLOR;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.82,.89,1);env.ambient_light_energy=.85;environment.environment=env;stage.add_child(environment)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-25,-25,0);light.light_energy=1.2;stage.add_child(light)
 var camera:=Camera3D.new();camera.position=Vector3(0,0,3);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.90;camera.current=true;stage.add_child(camera)
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://world/pond/models/encyclopedia/encyclopedia_manifest.json"))
 DirAccess.make_dir_recursive_absolute("res://assets/fish/encyclopedia_icons")
 var count:=0
 for e: Dictionary in rows:
  if e.status!="new":continue
  var model: Node3D=load(e.model_scene).instantiate();model.rotation_degrees.y=82;stage.add_child(model);model.freeze_preview()
  for frame in 2:await process_frame
  await RenderingServer.frame_post_draw
  var error:=viewport.get_texture().get_image().save_png("res://assets/fish/encyclopedia_icons/"+e.id+".png")
  assert(error==OK);model.queue_free();await process_frame;count+=1
 print("ENCYCLOPEDIA ICONS: ",count)
 viewport.queue_free();await process_frame;quit()
