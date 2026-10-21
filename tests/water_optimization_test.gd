extends SceneTree

var failures := 0
const OUTPUT := "res://exports/qa-water-optimization"
const COMPONENT := preload("res://world/pond/water_interactions.tscn")
const WATER_SHADER := preload("res://world/water.gdshader")

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 if value:
  print("PASS: ", message)
 else:
  failures += 1
  push_error(message)

func fixture(reference: Script = null) -> Node3D:
 var world := Node3D.new()
 var actor := Node3D.new()
 actor.name = "Player"
 world.add_child(actor)
 var plane := MeshInstance3D.new()
 plane.name = "Water"
 plane.mesh = PlaneMesh.new()
 var material := ShaderMaterial.new()
 material.shader = WATER_SHADER
 plane.material_override = material
 world.add_child(plane)
 var component := COMPONENT.instantiate()
 if reference != null:
  component.set_script(reference)
 component.name = "Response"
 component.player = actor
 component.water_surface = plane
 world.add_child(component)
 root.add_child(world)
 component.set_process(false)
 return world

func seed_events(component: Node, count: int, spread: bool) -> void:
 for i in 12:
  component.events[i] = Vector3(-100, 0, 0)
 for i in count:
  component.events[i] = Vector3(float(i % 3) * 0.07, 0.8, 0)
  component.event_positions[i] = Vector2(float(i % 4) - 1.5, float(i / 4) - 1.0) * (5.0 if spread else 0.4)

func benchmark(component: Node) -> Dictionary:
 var results := {}
 var rendered := RenderingServer.get_rendering_device() != null
 var gpu_path: bool = component.get("_using_gpu_field") == true
 if gpu_path:
  RenderingServer.viewport_set_measure_render_time(component.field_viewport.get_viewport_rid(), true)
 for scenario in [{"name": "one", "count": 1, "spread": false}, {"name": "four", "count": 4, "spread": false}, {"name": "twelve_clustered", "count": 12, "spread": false}, {"name": "twelve_spread", "count": 12, "spread": true}, {"name": "idle", "count": 0, "spread": false}]:
  seed_events(component, scenario.count, scenario.spread)
  var timings: Array[float] = []
  var gpu_timings: Array[float] = []
  var render_cpu_timings: Array[float] = []
  for iteration in 20:
   component.clock = 0.5 + float(iteration % 8) * 0.1
   var start := Time.get_ticks_usec()
   component._update_field()
   var ms := float(Time.get_ticks_usec() - start) / 1000.0
   if rendered:
    await process_frame
    await RenderingServer.frame_post_draw
   if iteration >= 4:
    timings.append(ms)
    if gpu_path and scenario.count > 0:
     gpu_timings.append(RenderingServer.viewport_get_measured_render_time_gpu(component.field_viewport.get_viewport_rid()))
     render_cpu_timings.append(RenderingServer.viewport_get_measured_render_time_cpu(component.field_viewport.get_viewport_rid()))
  timings.sort()
  results[scenario.name] = {"median_ms": timings[timings.size() / 2], "p95_ms": timings[ceili(timings.size() * 0.95) - 1]}
  if not gpu_timings.is_empty():
   gpu_timings.sort()
   render_cpu_timings.sort()
   results[scenario.name]["field_gpu_median_ms"] = gpu_timings[gpu_timings.size() / 2]
   results[scenario.name]["field_render_thread_median_ms"] = render_cpu_timings[render_cpu_timings.size() / 2]
 return results

func field_error(actual: Node, reference: Node) -> Dictionary:
 var maximum := 0
 var total := 0
 var samples := 0
 for scenario in [{"count": 1, "spread": false}, {"count": 4, "spread": false}, {"count": 12, "spread": false}, {"count": 12, "spread": true}]:
  seed_events(actual, scenario.count, scenario.spread)
  seed_events(reference, scenario.count, scenario.spread)
  for age in [0.1, 0.65, 1.4, 2.4, 2.8]:
   for component in [actual, reference]:
    component.clock = age
    component.player.position = Vector3(0.37, 0, -0.61) if age > 1.0 else Vector3.ZERO
    component._update_field()
   if actual._using_gpu_field:
    for frame in 2:
     await process_frame
    await RenderingServer.frame_post_draw
   var a: PackedByteArray = actual.get_field_image().get_data()
   var b: PackedByteArray = reference.field_image.get_data()
   for i in range(0, a.size(), 4):
    for channel in 3:
     var error := absi(a[i + channel] - b[i + channel])
     maximum = maxi(maximum, error)
     total += error
     samples += 1
 return {"max_byte_error": maximum, "mean_byte_error": float(total) / float(samples)}

func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 var candidate_world := fixture()
 var candidate := candidate_world.get_node("Response")
 var results := {"note": "Desktop timings per field update, not Android frame rate. GPU fields use viewport timing queries.", "candidate": await benchmark(candidate)}
 results["engine"] = Engine.get_version_info().get("string", "unknown")
 results["gpu_field"] = candidate._using_gpu_field
 var reference_path := OS.get_environment("LAKEBOUND_WATER_REFERENCE")
 if not reference_path.is_empty():
  var reference_world := fixture(load(reference_path))
  var reference := reference_world.get_node("Response")
  results["baseline"] = await benchmark(reference)
  results["field_error"] = await field_error(candidate, reference)
  expect(results.field_error.max_byte_error <= 4, "optimized height/normal field matches original within four encoding levels")
  expect(results.field_error.mean_byte_error < 0.15, "average field error remains below 0.15 of one encoding level")
  reference_world.free()
 else:
  # Verify propagation and stale-data clearing without the optional baseline.
  seed_events(candidate, 4, false)
  candidate.clock = 0.65
  candidate._update_field()
  expect(candidate.active_event_count == 4, "all four impulses remain active")
 candidate.clock = 10.0
 candidate._update_field()
 if candidate._using_gpu_field:
  for frame in 2:
   await process_frame
  await RenderingServer.frame_post_draw
 var neutral: PackedByteArray = candidate.get_field_image().get_data()
 var clear := true
 for i in range(0, neutral.size(), 4):
  clear = clear and neutral[i] == 128 and neutral[i + 1] == 128 and neutral[i + 2] == 128
 expect(clear, "expired field clears old wave data after camera/player movement")
 if candidate._using_gpu_field:
  expect(RenderingServer.viewport_get_update_mode(candidate.field_viewport.get_viewport_rid()) == RenderingServer.VIEWPORT_UPDATE_DISABLED, "GPU data viewport stops rendering after expiry")
  expect(candidate.water_material.get_shader_parameter("interaction_field_active") == false, "idle water skips the interaction texture sample")
 expect(candidate.enable_surface_displacement and candidate.field_resolution == 256, "surface displacement and original field detail remain enabled")
 var filename := "benchmark.json" if candidate._using_gpu_field else "benchmark-cpu-fallback.json"
 var file := FileAccess.open(OUTPUT + "/" + filename, FileAccess.WRITE)
 file.store_string(JSON.stringify(results, "  "))
 file.close()
 print(JSON.stringify(results))
 candidate_world.free()
 print("WATER OPTIMIZATION RESULT: ", failures, " failures")
 quit(failures)
