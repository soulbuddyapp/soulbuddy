# SoulBuddy App Icon Design

## Purpose

Replace the default Flutter launcher mark with a distinctive SoulBuddy icon that belongs to the app's sacred remembrance and Altar visual language.

## Mark

The icon uses one compact, hand-hewn limestone remembrance tablet on a deep forest field. A restrained covenant-gold incision rises through the tablet and opens near its upper third, suggesting received light, grace, and a path held in memory without becoming a literal cross, plant, flame, or letter.

## Visual constraints

- Deep forest background: `#174334`.
- Limestone emblem using the existing limestone and parchment family.
- Covenant-gold central incision: `#B5893E`.
- No branches, vines, hands, hearts, books, candles, people, text, monograms, or denominational symbols.
- The slab must remain natural and irregular, but not resemble a gravestone.
- Generous safe padding must preserve the mark under circular, squircle, and rounded-square launcher masks.
- Detail must remain legible at the Android mdpi launcher size.

## Android integration

The approved square master artwork is stored with the Android launcher resources. It is mechanically resized into the standard mdpi through xxxhdpi mipmap sizes and continues to use the existing `@mipmap/ic_launcher` manifest reference. The icon is verified by inspecting the master and generated launcher sizes, rebuilding the APK, installing it on each connected physical device, and launching the application.

## Acceptance criteria

- No default Flutter logo remains in any Android launcher density.
- Every launcher bitmap is square and matches the Android density dimensions.
- The debug APK builds successfully.
- The updated package installs and launches on the connected physical Android devices.
