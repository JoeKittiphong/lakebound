# Loading lake scenery

`features/loading/cinematic/loading_cinematic.tscn` uses the gameplay
`world/water.gdshader` through `lake_surface.tres`. Ripple noise settings match
the river (seed 37, 256px normal map, frequency 0.045, three octaves). Default
water color, absorption, sky reflection and shore wash use the same shader
parameters as gameplay. A lake bed at -2.8m provides shallow-water depth behind
the transparent surface. No screen-color copy or extra viewport is added.

Six authored scenic fish reuse existing tilapia and golden barb models and
their swimming animations. `scenic_fish.gd` moves each around its saved center
with Inspector-editable ellipse radius, phase and speed. They are decorative
and never update collection, economy or fishing records.

`Scenery/BoatFloat` reuses `fishing_boat_b.glb`, with quiet vertical bobbing and
small pitch/roll in the cinematic controller. The visual model has no driving
or collision controller in this scene. Adjust its position and yaw in the
scene. Loading and the continuous main-menu reveal share this scenery.

Verification: loading motion, cooler placement, loading flow and the cinematic
render test. The render test checks the shared water shader, fish movement and
underwater positions, boat waterline, and captures arrival/cast/wait/menu at
desktop, wide and tablet sizes. Android device rendering remains unverified.
