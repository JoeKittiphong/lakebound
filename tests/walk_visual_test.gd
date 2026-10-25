extends SceneTree

func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 root.size = Vector2i(720, 720)
 var scene: Node3D = load("res://actors/player/character_preview.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 var player: AnglerPlayer = scene.get_node("Player")
 var camera: Camera3D = scene.get_node("Camera3D")
 var shader := Shader.new()
 shader.code = "shader_type spatial; void fragment(){ float tile=mod(floor(UV.x*24.0)+floor(UV.y*24.0),2.0); ALBEDO=mix(vec3(0.12,0.16,0.16),vec3(0.22,0.27,0.26),tile); ROUGHNESS=1.0; }"
 var material := ShaderMaterial.new()
 material.shader = shader
 scene.get_node("Floor/Mesh").material_override = material
 player.global_position = Vector3(0, 0, 2)
 for i in 5:
  await physics_frame
 Input.action_press("move_forward")
 var output := OS.get_environment("LAKEBOUND_QA_DIR") + "/walk_matched"
 DirAccess.make_dir_recursive_absolute(output)
 for i in 24:
  await create_timer(1.0 / 12.0).timeout
  camera.global_position = player.global_position + Vector3(2.4, 1.5, -3.3)
  camera.look_at(player.global_position + Vector3(0, 0.85, 0))
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output + "/walk_%02d.png" % i)
 Input.action_release("move_forward")
 print("WALK VISUAL RESULT: 24 frames rendered at measured ground speed")
 scene.queue_free()
 await process_frame
 quit()
