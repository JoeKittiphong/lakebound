# Lakebound 0.1.6

Prepared 21 October 2026 for closed Alpha, from current source. Includes river environment, 16-species catalog and revised retrieval, tension, fish behavior and controls.

- Version code: 7; package: com.zylaah.lakebound
- Bundle: exports/android/lakebound-0.1.6-closed.aab
- Size: 63,902,506 bytes
- SHA256: 58f931fe5a46360b2312c1f8bc01d92d09e03f05b9894a84db55f2d2767254e5
- Original upload certificate SHA256: 22:14:8E:75:33:32:B6:E2:5C:4C:F6:3A:54:E1:D1:60:4F:2A:48:FC:2E:CB:77:24:59:21:C1:A4:DC:69:94:B7
- Target API 36, minimum 28, VIBRATE only; release manifest, ZIP integrity, secret exclusion and ARM64 16KB ELF checks passed.

Fresh automated suites passed: startup_flow, camera_movement, bait_retrieval, tension_haptics, fish_behavior, fishing_simulation, fish_catalog_fishing, fish_models, refactor_boundaries, collection, fishing_visual, active_scene_movement, rod_tension, fish_render. Logs: exports/qa-0.1.6 in workspace root.

Known verification limitation: legacy water_render_test still targets World/Lake and LakeBed from the removed lake scene, uses old coordinates, and fails against the river scene. It is not reported as passed. River integration/render checks run separately. No physical Android test performed.

Console: Google Play accepted bundle 7 (0.1.6). Alpha release 6 saved and submitted; publishing overview visibly confirms Changes in review. Quick checks precede content review. Managed publishing remains enabled. Prior published bundle shown as 5 (0.1.4). No blocking validation errors; optional mapping/native debug symbol warnings only. Estimated new install 37.9 MB; update 7.65 MB. Proof: exports/play-store/0.1.6-submitted.png.

River renderer completed with exit 0 and no script errors (exports/river-render-current-0.1.6.log). River integration has passed geometry, casts, both bank trails, bridge and physical ford checks at the last observation; remaining integration flow was still running and is not claimed passed here.
