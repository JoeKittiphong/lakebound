extends SceneTree
var failures := 0
var checks := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")
func _initialize() -> void:
 call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: "+message)
func frames(count: int = 6) -> void:
 for index in count: await process_frame
func capture(name: String) -> void:
 await frames()
 if DisplayServer.get_name() != "headless" and not output.is_empty():
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.path_join(name+".png"))
func material_mesh(node: Node, needle: String) -> MeshInstance3D:
 if node is MeshInstance3D and node.mesh != null:
  for surface in node.mesh.get_surface_count():
   var material = node.get_active_material(surface)
   if material is BaseMaterial3D and material.normal_texture != null and needle in material.normal_texture.resource_path:
    return node
 for child in node.get_children():
  var found := material_mesh(child,needle)
  if found != null: return found
 return null
func run() -> void:
 root.size=Vector2i(1280,720)
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.save_path=output.path_join("profile.cfg")
 profile.data=profile.defaults()
 root.get_node("FishCollection").recording_enabled=false
 for region in RegionCatalog.MAPS:
  var game:Node3D=load(region.scene).instantiate()
  game.economy_enabled=false
  game.get_node("HUD/FishingHUD/SafeArea/FirstCatch").active=false
  root.add_child(game)
  current_scene=game
  game.get_node("FishingEffects").audio_enabled=false
  await frames(8)
  game.process_mode=Node.PROCESS_MODE_DISABLED
  game.get_node("HUD/FishingHUD/SafeArea/FirstCatch").hide()
  expect(game.get_node("PondEcosystem").fish.size()>0,"existing fish population: "+region.id)
  expect(get_nodes_in_group("player").size()<=1,"no accumulated players: "+region.id)
  await capture("map_"+region.id)
  if region.id=="river":
   game.get_node("HUD").visible=false
   var camera:=Camera3D.new()
   game.add_child(camera)
   camera.current=true
   camera.fov=55
   for token in ["wooden_bridge","reference_rocks","rock_clusters"]:
    var mesh:=material_mesh(game,token)
    expect(mesh!=null,"closeup material exists: "+token)
    if mesh==null: continue
    var target:Vector3=mesh.global_transform*mesh.get_aabb().get_center()
    camera.global_position=target+Vector3(2,2,3.5)
    camera.look_at(target)
    await capture("close_"+token)
  game.queue_free()
  current_scene=null
  await frames(10)
 print("TEXTURE VISUAL: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
