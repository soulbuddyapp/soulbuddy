# Sacred Piece Visual Guides Design

**Status:** Approved 2026-09-09

## Purpose

Give SoulBuddy a recognisable visual language for the distinct parts of a person's spiritual life. Each meaningful object receives a consistent, accessible icon medallion, while Today and formation use one restrained illuminated guide to draw attention to the current practice.

## Considered approaches

1. **Full illustrated sanctuary screens.** Rich but expensive, slow to load, and likely to crowd real content.
2. **Generic Material list styling.** Fast but does not give each spiritual practice a memorable identity.
3. **Sacred pieces — selected.** Warm stone-like surfaces, semantic icon medallions, and one illuminated focal guide per screen. This carries the feeling of the supplied references while keeping content, controls, and accessibility primary.

## Visual grammar

- **Parchment and limestone surfaces** establish calm and weight. Existing Covenant and Grace tokens remain the source of colour and elevation.
- **Covenant gold** signals current attention, selected navigation, and a guide. It never carries status without text or an icon.
- **A medallion** is a small, tactile circular surface that contains one outline icon. Its selected state gains a restrained gold ring and filled icon.
- **A guide** is a short light rail or focused surface that identifies the current practice. It is not a streak, score, progress meter, or reward.
- **Scenic imagery** is optional and reserved for a single focal surface, such as formation. The first implementation uses code-native light and surfaces, not generated character or sacred-person imagery.

## Sacred-piece icon contract

| Piece | Icon meaning |
|---|---|
| Today | dawn / daily return |
| Prayer | joined hands |
| Goal | compass / faithful direction |
| Person | person silhouette |
| Remember | bookmark and voice mark |
| Altar | oil lamp |
| Circle | connected people |
| Scripture | open book |
| Meditation | breath rings |
| Sacred Hour | sun and clock |
| Orientation | eight-step path |

Icons use one Material-outline family with filled selected variants where available. They have labels in semantics and text labels when they represent a standalone action. No emoji, decorative icons, or colour-only states are permitted.

## Screen application

### App shell

The five existing destinations retain their routes and labels. Their icons become part of the sacred-piece system: dawn for Today, compass for My practice, person for Persons, bookmark for Remember, and connected people for Circles. The selected destination uses the existing primary colour plus a compact gold indicator; unselected destinations remain high contrast.

### Today

The existing current guidance card receives the appropriate medallion and a narrow gold light rail. Its copy continues to state a spiritual purpose or invitation rather than describe a UI action. There is one guide surface at a time; all other daily sections remain compact.

### My Collection

Goals and personal prayers remain one chronological collection with existing filters and sorting. Each row gains a goal-compass or prayer-hands medallion. It remains a 64dp compact target, with reorder controls available only for goal-priority sorting.

### Formation

The current Nugget receives the orientation-path medallion. Completion and progress remain factual and textual. The visual can show an eight-marker path but never represents spiritual standing.

### Supporting experiences

Altar, Persons, Remember, Circles, Scripture, meditation, Sacred Hours, and the persistent player use the central icon mapping when they show a type or source. They do not add a decorative card merely to display an icon.

## Interaction and accessibility

- All interactive medallions have a minimum 48dp touch target, a visible pressed state, and a semantic label.
- Decorative guide effects are excluded from semantics.
- Normal text meets 4.5:1 contrast. The medallion icon and label make type visible without depending on colour.
- Motion uses opacity and transform only, lasts 150–300ms, and resolves immediately when reduced motion is enabled.
- At 200% text, medallions stay aligned with the first line of content, text wraps, and the guide yields space before any control clips.

## Data and scope

The icon mapping is presentation-only and derives from existing route, content, and session types. No database schema, progress state, analytics event, new asset pipeline, or network request is needed.

The first slice establishes the reusable mapping and medallion, then applies it to navigation, Today guidance, My Collection, formation, and the spiritual mini player. It preserves all existing routes, actions, filters, and storage behavior.
