# Lure direction progress

Direction sequences have no timing window, timeout or required hold duration. A held direction counts once; release before repeating the same direction. Wrong directions reset both formula and fish interest to zero. Partial progress is retained regardless of how long the player pauses. Full progress stays locked while a compatible fish is in detection range. If no eligible fish is present on completion, or all candidates leave while waiting, the formula and fish interest reset with a visible no-fish retry warning. This checks current fish positions, food preference, depth, hunger and caution using the same predicate as simulation; stale follower counts cannot keep the meter full.

Each correct direction fills an equal part of the interest meter. Frog: 3; pencil: 6; metal jig: 7. Other lures use authored item-specific sequences or their movement-family fallback (3–5). No successful action expires while fish are approaching.

Existing compatible, hungry, non-cautious fish at the correct depth pursue the lure. Once within 0.65 m, they evaluate a bite every 0.7 seconds: partial meters have a progress-scaled probability; full meters guarantee the bite on the next evaluation. Full does not spawn fish or teleport them. HUD explains no nearby fish, incompatible bait, wrong depth, caution/hunger, pursuit and the full-meter wait. Physical lure movement remains independent.

Validation: tests/lure_rhythm_test.gd covers arbitrary speed, held input, wrong-direction resets, recipe lengths, actual pursuit/early bites/guaranteed bites and native mobile joystick input. Rendered landscape layouts at 1280×720, 2400×1080 and 1024×768. Physical phone testing remains separate.
