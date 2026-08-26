# First-Use Ritual Implementation Plan

1. Add test-first local completion storage and a Riverpod-backed first-use gate.
2. Add test-first three-scene welcome UI with concise copy, slab progression, accessible paging, skip, and final handoff callbacks.
3. Place the gate above the routed application and route completion to either Today or the prayer library.
4. Refine the empty Today guide to reflect the Pray → Act → Remember rhythm without adding vertical bloat.
5. Run focused tests, the full Flutter suite, analyzer, Android build, then install and inspect the experience on the connected physical device.
