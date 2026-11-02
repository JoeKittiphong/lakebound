# Loading rainforest scenery

Open `features/loading/cinematic/loading_cinematic.tscn`. The saved `Scenery/LoadingJungle` instance points to `loading_jungle_dressing.tscn`; all batch transforms, colors, meshes and distance limits are serialized and editable in the Inspector. This change is local to the loading cinematic.

## Composition

779 authored instances: 206 broadleaf trees, bushes, grasses, ferns, taro, bananas, layered boulders/slabs, 46 submerged seaweed instances and 40 lily-pad clusters. Near trees use the existing 871-triangle `tree_b_mid`; distant trees use the 237-triangle `tree_a_far` including its trunk. Rocks are 188/116 triangles per stone. The old conifers and concept rocks have been removed from this scene. The distant treeline is a generated transparent image on one saved quad; foreground ground uses the existing grass texture with world-space mapping.

## Rendering

63 spatial MultiMesh batches use the existing editor-visible authored batch component. Foliage shares the 2048 atlas with alpha scissor threshold 0.42; no alpha-blended foliage fades. Opaque rocks and lily geometry avoid transparent rendering. Far trees, bushes, aquatic plants and the backdrop do not cast shadows. Distance limits: small foreground plants 40–70m, near trees 85m, far trees 150–220m. These are deliberately selected mesh LOD variants for the fixed cinematic camera, rather than an additional per-frame LOD switching controller. Distance margins provide hysteresis. The generated backdrop has mipmaps and VRAM compression enabled.

Only the exact intended named mesh is extracted from each existing GLB. Those source files include unrelated historical export meshes, which are deliberately excluded. Roots sample the actual faceted bank triangles; seaweed tops remain submerged. The dock/walk/cast corridor remains clear.

`tools/build_loading_jungle.gd` is an offline deterministic authoring tool (seed 884127), not a runtime generator. It regenerates the dressing subscene and extracted mesh resources. Do not run it over manual dressing edits without intending to replace them. The parent scene owns removal of old props, grass material and the dressing instance.

## Verification

Godot 4.7.2, Mobile D3D12, GTX1660Ti, 1280x720 waiting frame:

- Previous: 238 draw calls, 115606 rendered primitives.
- Revised: approximately 113 draw calls, 102451 rendered primitives (frame-dependent).
- Dense scenery audit: 779 instances / 206 trees / 63 batches; zero failures. Checks reload persistence, foliage scissor/opaque material modes, finite culling limits, far-tree shadow exclusion and submerged seaweed bounds.
- Loading motion: 43 checks, zero failures, including playback speeds 0.5/1/2.
- Cooler contact and loading-flow recovery/start regressions: zero failures.
- Actual GPU captures: establishing/walking/cast/waiting plus dedicated loading-screen 1280x720, 1600x720 and 1024x768 captures. Dock, actor, line and bobber remain visible.

Evidence: `exports/loading-jungle-qa/`. Run `tests/loading_jungle_test.gd`, `loading_jungle_visual_test.gd`, `loading_motion_test.gd`, `loading_cooler_test.gd` and `loading_flow_test.gd`. Set `LAKEBOUND_QA_DIR` to an existing absolute capture directory for visual tests. No phone was connected: these render counts are desktop measurements, not measured mobile FPS.
