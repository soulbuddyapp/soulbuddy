# SoulBuddy Signature Illustration Design

## Goal

Give SoulBuddy one memorable visual expression of its spiritual-formation framework without adding decorative clutter or making first-use screens scroll.

## Visual concept

The signature illustration is a luminous olive tree growing beside a small stone memorial. Light reaches the roots, the trunk rises with quiet strength, fruit appears on the branches, and a few leaves extend outward. The image expresses one movement:

```text
GRACE → FORMATION AND MEMORY → PRAYER AND SURRENDER → FRUIT → TRANSMISSION
```

The visual must not suggest that spiritual practice purchases grace. Grace is the source; disciplined response forms character; fruit benefits others; memory and transmission allow good to continue.

## Art direction

- Quiet editorial illustration rather than religious clip art.
- Deep forest, muted jade, warm stone, and restrained gold light.
- Organic texture and gentle depth, with a calm focal center.
- No people, faces, halos, church architecture, text, logos, scores, streaks, coins, treasure, or ornamental religious kitsch.
- Transparent or cleanly isolated composition that works in both light and dark themes.
- No important details at the outer edges; the asset must tolerate responsive cropping.

## Placement and behavior

Today is the primary home for the illustration. It appears as a compact atmospheric hero inside the new-user guide, above or beside the existing framework-grounded invitation depending on width. The two actions remain visible in the initial normal-text phone viewport. At 200% text scale the visual reduces or yields space to content so controls remain readable and reachable.

The illustration is a single reusable asset, not a new illustration system. Other screens continue to use restrained icons and existing empty-state layouts. This preserves visual identity without multiplying decoration.

## Accessibility and performance

- The image has the semantic label: “An olive tree growing from remembered grace and bearing fruit for others.”
- The image is excluded from duplicate semantics when adjacent copy already communicates the same idea.
- The asset is compressed for mobile delivery and loaded from the bundled Flutter asset manifest; it has no network dependency.
- The layout is verified in light and dark themes, on a 320×640 shell viewport, and at 200% text scaling.
- The empty-state actions must not require scrolling at normal text scale.

## Verification

- An asset contract test proves the bundled image exists and remains within a practical byte budget.
- Today widget tests prove the visual is present, meaningful, and does not push the empty state below the real bottom navigation area.
- Existing reduced-motion, text-scale, and navigation behavior remains unchanged.
- The final Android build is inspected on an emulator and installed on the connected physical device without clearing user data.
