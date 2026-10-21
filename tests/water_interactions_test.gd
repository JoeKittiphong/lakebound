extends SceneTree

var failures := 0
const OUTPUT := "res://exports/qa-water-interactions"

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 if value:
  print("PASS: ", message)
 else:
  failures += 1
  push_error(message)

func capture(label: String) -> void:
 for i in 8:
  await process_frame
 await RenderingServer.frame_post_draw
 expect(root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png") == OK, label)

func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 root.size = Vector2i(1280, 720)
 root.get_node("FishCollection").recording_enabled = false
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 var water = scene.get_node("WaterInteractions")
 var player: Node3D = scene.get_node("Player")
 var ecosystem = scene.get_node("PondEcosystem")
 var definition = scene.get_node("World").definition
 water.set_process(false)
 ecosystem.set_physics_process(false)
 player.set_physics_process(false)
 scene.get_node("FishingController").set_physics_process(false)
 for fish in ecosystem.fish:
  fish.position.y = 3.0
 water._sample_contacts()
 expect(water.emitted_count == 0, "dry bank makes no contact ripple")
 var z := 42.0
 var x: float = definition.center_at(z) - definition.half_width_at(z) + 1.8
 var contact_point := Vector3(x, definition.ground_height(Vector2(x, z)), z)
 player.global_position = contact_point
 water._sample_contacts()
 expect(water.emitted_count == 1, "entering actual shallow water emits one ripple")
 water._sample_contacts()
 expect(water.emitted_count == 1, "standing still does not spam ripples")
 player.global_position.z += 0.6
 water._sample_contacts()
 expect(water.emitted_count == 2, "wading movement emits footstep wake")
 var fish = ecosystem.fish[0]
 fish.position = Vector3(x + 2.0, 0.12, z)
 water._sample_contacts()
 expect(water.emitted_count == 3, "fish surfacing emits a ripple")
 water._sample_contacts()
 expect(water.emitted_count == 3, "surface threshold does not spam duplicate events")
 fish.position.y = 0.5
 water._sample_contacts()
 fish.position.y = 0.12
 water._sample_contacts()
 expect(water.emitted_count == 4, "resurfacing after diving emits another ripple")
 var before: int = water.emitted_count
 player.global_position = Vector3(definition.center_at(definition.bridge_z), 0.8, definition.bridge_z)
 water._sample_contacts() # final exit ripple at the previous contact
 before = water.emitted_count
 player.global_position.x += 1.0
 water._sample_contacts()
 expect(water.emitted_count == before, "walking above water on bridge emits no contact ripple")
 water.emit_ripple(player.global_position + Vector3(100, 0, 0))
 expect(water.emitted_count == before, "distant events are culled")
 for i in 40:
  water.emit_ripple(player.global_position + Vector3(i * 0.01, 0, 0))
 expect(water.events.size() == 12 and water.event_positions.size() == 12, "burst events retain fixed twelve-event budget")
 water._process(water.ripple_lifetime + 0.1)
 expect(water.active_event_count == 0, "expired ripples leave the height field")
 # Return to the bank and display a fish surfacing next to a stationary wader.
 player.global_position = contact_point
 for i in 12:
  water.events[i] = Vector3(-100, 0, 0)
 water.fish_contacts.clear()
 water.was_in_water = false
 water._sample_contacts()
 water._process(0.65)
 for i in 2:
  await process_frame
 await RenderingServer.frame_post_draw
 var field_snapshot: Image = water.get_field_image()
 var positive := false
 var negative := false
 var slope := false
 for z_index in range(0, water.field_resolution, 2):
  for x_index in range(0, water.field_resolution, 2):
   var sample: Color = field_snapshot.get_pixel(x_index, z_index)
   positive = positive or sample.b > water.NEUTRAL + 0.005
   negative = negative or sample.b < water.NEUTRAL - 0.005
   slope = slope or absf(sample.r - water.NEUTRAL) > 0.01
 expect(positive and negative and slope, "contact creates real crest, trough and normal slope data")
 expect(water.surface_detail.mesh.get_faces().size() > 4096, "near surface has tessellation for actual displacement")
 expect(water.water_material.get_shader_parameter("detail_patch_enabled") == true, "near patch replaces the original water instead of overlay rings")
 scene.get_node("HUD").hide()
 scene.get_node("CameraRig").set_process(false)
 var camera: Camera3D = scene.get_node("CameraRig/Camera3D")
 camera.global_position = Vector3(x + 6, 6, z + 8)
 camera.look_at(Vector3(x + 1.4, -0.18, z))
 scene.get_node("FishingEffects")._update_fish_visuals()
 await capture("surface-contact")
 water._process(0.5)
 await capture("surface-propagation")
 root.size = Vector2i(1600, 720)
 await capture("surface-contact-wide")
 root.size = Vector2i(1280, 720)
 camera.global_position = Vector3(x + 6, 1.7, z + 5)
 camera.look_at(Vector3(x + 1.8, -0.18, z))
 water.emit_ripple(Vector3(x + 2.0, 0, z), 1.2)
 water._process(0.45)
 await capture("surface-close")
 if OS.get_environment("LAKEBOUND_WATER_CLIP") == "1":
  root.size = Vector2i(640, 360)
  for i in 12:
   water.events[i] = Vector3(-100, 0, 0)
  water.emit_ripple(Vector3(x + 2.0, 0, z), 1.2)
  for frame in 32:
   water._process(0.05)
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUTPUT + "/motion-%02d.png" % frame)
 print("WATER INTERACTIONS RESULT: ", failures, " failures")
 quit(failures)
