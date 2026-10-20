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
