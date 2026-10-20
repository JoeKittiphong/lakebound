# Replaceable 3D reels

`baitcaster.tscn` is the first overhead charcoal/turquoise double-paddle model. Its meshes, materials, mounting foot, spool, frame and crank are saved in the scene and editable before running.

The UI in `shared/ui/reel_control.tscn` provides a transparent isolated 3D viewport, orthographic overhead camera and lighting. `shared/ui/reel_visual.gd` drives the model; hidden reels disable viewport rendering.

To add a model, create a Node3D scene with direct Node3D children named `Spool` and `Crank`. Their local X axes are the shared shaft direction; place each pivot at its actual axle and model its geometry under that pivot. The controller sets their X rotations and the root Z tilt. Use the first model's scale and framing as a reference.

Assign the PackedScene to the Reel Scene Inspector property, or call `equip(scene)` when an equipment selection is made. Invalid scenes are rejected before replacing the current model. This prepares visual swapping; ownership, prices and an equipment selection menu are not implemented here.

Verified in Godot 4.7.2: real mesh pivot animation, reversal, neutral/drag behavior, replacement and invalid-model rejection, walking and camera multitouch, full landing flow, and 16:9 / wide rendered UI. Normal-permission test log: `reel3d-verified.log` (zero errors). Physical mobile performance remains unmeasured.
