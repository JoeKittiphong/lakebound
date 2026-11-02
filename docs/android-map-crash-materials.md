# Android map entry crash: line materials

Device reproduction: realme RMX3840, Android 16, Play build 0.1.23 (24).
The captured game log immediately before native SIGSEGV on VkThread reports
`Cannot open file res://features/equipment/detailed/materials/braid.tres`.
The archived release bundle contains mono but lacks braid, fluoro and fly materials.

`DetailedReelVisual.set_line_style()` previously constructed resource paths at runtime.
The selected-resource export dependency scan could not include these materials.
It also duplicated the result of the failed load without checking it.

The reel now preloads all four supported materials in a registry and guards material
duplication. The selected export manifest was regenerated. Release verification now
rejects bundles missing any line material or its remap target.

Source equipment regression: 206 checks, zero failures.
Evidence and isolated physical-device QA build are under
`output/android-map-crash/` in the workspace. The QA app uses a separate Android
package and does not overwrite the Play installation or its save data.

This diagnosis does not establish a Vulkan driver defect. The renderer and ABI
were preserved.

Physical-device QA passed on the same RMX3840 using Vulkan Mobile (Adreno 710):
all 8 reel families with all 4 line materials, followed by all 6 actual map scenes
with the profile equipped with braid. Result: 76 checks, zero failures,
`CRASH_QA_PASS`; no Godot/script errors or native crash in this run.
Evidence: `output/android-map-crash/device/qa_run.log` (PID 27048).
This verifies the isolated debug APK; the installed Play build remains 0.1.23
until a fixed release is distributed.
