# Runtime GDScript warnings cleanup — 1 November 2026

Godot 4.7.2 Language Server diagnostics were collected for every GDScript under actors/, data/, features/, shared/, world/ (97 files).
Before: 19 warnings. After: 0 warnings and 0 errors.
Evidence: output/debugger-warnings/diagnostics_before.json and diagnostics.json.

Changes:
- Rename local variables that shadow Node/Control properties or other functions (name, ready, position, text, entry, definition, visible).
- Initialize the largest-fish accumulator explicitly to null.
- Express intentionally truncated page/grid indexing with floori and a floating divisor; preserve the original nonnegative index behavior.
- CommerceGateway's two inherited platform callback signals are intentionally not emitted by the disabled base implementation. Add narrow unused_signal annotations with an explanatory adapter-contract comment. No purchase/reward emission or validation behavior was added; global warnings remain enabled.

Regression verification:
- fishing_map_data_test: 43 checks, 0 failures.
- missions_test: 76 checks, 0 failures. The fixture now honors LAKEBOUND_QA_DIR rather than requiring writes to the user's real application directory.
- fish_health_test: 60 checks, 0 failures.
- packed_memory_smoke_test: stable resource counts [3097,3097,3097,3097] and node counts [3,3,3,3], 0 failures.
- GPU water_interactions_test run to exercise renamed stamp counters.

Host sandbox diagnostics about user:// log/cache writes and the Windows certificate store are environment diagnostics; warnings are not disabled to conceal them. Save-failure warnings remain intact so actual persistence failures are still reported.
