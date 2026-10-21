# Lake water, mobile baseline

Open `pond.tscn`. The saved Lake, LakeBed, lighting and sky are editable before
running. Lake > mesh > material > Shader Parameters controls water appearance.
LakeBed > material_override controls sand, silt, grass and subtle shallow caustics.

This is the low-cost baseline, not a measured low-end-device performance claim:

- Mobile renderer preserved; one 2-triangle water plane, one transparent layer.
- One nearest depth-buffer sample and two mipmapped normal samples per water pixel.
- Shared seamless 256 x 256 normal texture, generated from FastNoiseLite on load.
- No screen-color readback/refraction, SSR loops, reflection cameras, reflection
  probes, volumetric fog or subdivided moving water geometry.
- Authored bed: 3,840 triangles, no collision or shadow casting. It slopes from
  the bank toward a 14 m basin, with raised distant shores.
- Caustics are a subtle procedural approximation on the bed, not light simulation.
- Fish visual pool stays at seven; shallower fish have priority after the active
  hooked/landed fish. Simulation population is unchanged.

Water height is -0.18 m. Fish records store positive depth, now rendered at
`water_height - record.position.y` without compressing depth. By default fish
deeper than 5 m do not consume visual slots. Absorption uses the camera ray's
underwater distance to the closest opaque object (including a fish), so fish
near the surface remain visible even above the deep bed. Keep underwater fish
materials opaque; transparent objects are not included in the depth buffer.

The three visual zones blend continuously: clear surface, blue-green middle
depth, dark deep water. They are not stacked transparent meshes. Higher
`absorption` hides fish faster; `color_depth` controls the shallow-to-deep hue;
`ripple_strength`, `wind_speed` and `surface_roughness` tune the surface.
These defaults are for viewing from above, not a submerged camera.

## Surface movement and contacts

The shared shader now has stronger normal ripples and gentle long swells.
`shore_wave_strength`, `shore_wave_depth`, `shore_wave_speed` and `shore_color`
control the slow shoreward wash. This reuses the existing depth sample and also
forms soft wash near shallow rocks; it is an artistic surface effect, not a
fluid simulation or displacement of the collision surface.

The active river gameplay scene instances `water_interactions.tscn`. Its Inspector
references point to the Player root, World, RiverWater and PondEcosystem; no character mesh,
bone or animation names are used. Replacing the character's visual model does
not require changing these effects. Contact uses `PondDefinition.is_wading`,
so the river's bridge and jetty are excluded. A future map should implement this
geometry query to describe its own walkable water.

Surface fish excite expanding, damped wave packets when they enter the top 0.22 m.
Moving surface fish can excite another packet after 1.2 seconds; hysteresis
prevents threshold flicker. Entering/leaving water and moving 0.48 m while wading
also excite the surface. Standing still does not continually emit waves.

Twelve fixed event slots feed a 256 x 256 HDR height/normal field covering 48 m
around the player. On Mobile/Forward+, an authored 2D-only SubViewport clears
to neutral and additively stamps only small impulse quads using one MultiMesh.
The CPU submits at most twelve transforms/parameters, without looping over
pixels, uploading an image or reading GPU data back. The float target preserves
signed accumulation of overlapping waves. It has no 3D camera, MSAA or river
rendering. It updates at most 20 Hz while waves are alive, clears once on expiry
and then stops rendering while idle. Contact queries remain at 10 Hz.

`use_gpu_field` is enabled by default. Headless QA and Compatibility use a CPU
fallback with persistent sparse buffers, annulus-only stamping and a cached
radial kernel. The default Mobile path does not allocate these buffers.

The water shader samples the field once per affected fragment to change its
actual surface normal, lighting and sky reflection. A serialized 16 x 16 m
SurfaceDetail mesh (8,192 triangles) follows the player and reads the same height
field in its vertex shader. It displaces the surface by a few centimetres and
blends displacement to zero at its edges. The main plane discards exactly this
footprint so two transparent water layers do not overlap. Outside this patch,
contact waves affect normals only. There are no painted ring meshes. Field
sampling is disabled when there are no impulses, and restricted to their active
bounds otherwise. Distant water skips the fine normal sample once detail has
faded, and deep water skips shoreline-wave calculations. The original near
mesh, 256px field, wave amplitudes and update rate are retained.

Tune `wave_amplitude`, `wavelength`, `wave_speed`, `field_resolution` and
`field_update_interval` on WaterInteractions. For a cheaper device profile,
turn off `enable_surface_displacement` to keep the responsive normals on the
original plane, and/or use a 128 x 128 field. The sky approximation is controlled
by the water material's `reflection_horizon` and `reflection_zenith` colors;
retune these when changing the scene sky.

This adds one texture lookup for affected water fragments/near vertices, plus
two small 2D draws into the field target per update (background and batched
impulses). It still uses no screen-color copies, SSR or reflection cameras.
`get_field_image()` is an explicit diagnostic readback used only by tests;
production rendering samples the viewport texture directly. This is an
analytic wave approximation rather than a fluid solver. Real-device profiling
is required for the final mobile budget.

`tests/water_interactions_test.gd` checks actual river entry, stationary contact,
wading steps, surfacing/diving, bridge exclusion, distance culling, pool capacity
and expiry, crest/trough/normal field values, and the displaced surface setup,
with rendered shore captures at 1280x720 and 1600x720. Set
`LAKEBOUND_WATER_CLIP=1` to also capture 32 motion frames at 640x360.

`tests/water_optimization_test.gd` benchmarks one, four and twelve concurrent
impulses, clustered and spread apart, plus idle. Run with a real renderer for
GPU field/render-thread timings. Set `LAKEBOUND_WATER_REFERENCE` to the saved
pre-optimization script resource to compare CPU cost and quantized field error.
The comparison exercises multiple ages, overlap, player motion and expiry.
Results are written to `exports/qa-water-optimization/benchmark.json`; desktop
timings do not imply Android frame rate. Timing comparisons are diagnostic,
not pass/fail thresholds that would be unstable across machines.

Measured on the desktop GTX 1660 Ti with Godot 4.7.2 Mobile/D3D12: twelve spread
impulses took about 8.28 ms median in the original CPU field generator versus
0.067 ms script submission after optimization. The added field pass measured
about 0.053 ms on the render thread and 0.047 ms on the GPU. These are separate
pipeline measurements, not total game frame time or expected phone timings.
Field comparisons against the original across ages, overlapping events, motion
and expiry differed by at most one level in an 8-bit channel. Real displacement,
the 8,192-triangle near mesh, 256px field and 20 Hz updates remain enabled.

## Validation and device follow-up

`tests/water_render_test.gd` checks bounded fish visuals, actual visual depths,
deep-fish culling and scene resources, and captures gameplay, depth comparison,
widescreen and shallow shore with a real renderer. Headless rendering cannot
validate the water shader visually.

Before calling this low-end ready, test on the intended Android phone at native
resolution, during fishing and camera movement, for at least 10 minutes. Target
30 fps (33.3 ms frame budget) with stable frame times after warming up. Record
device, resolution, temperature and GPU time. Desktop FPS is not a substitute.
If fill rate is the bottleneck, evaluate 3D resolution scaling while retaining
native-resolution HUD; do not automatically change the project's renderer.
Turning bed `caustic_strength` to zero simplifies the look but is not a guaranteed
GPU optimization because its arithmetic remains in this shader.
