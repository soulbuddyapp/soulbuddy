# SoulBuddy Living Vine Visual Language Design

## Goal

Give SoulBuddy one coherent visual language for daily spiritual life, grounded in Christ's words: "I am the vine; you are the branches." The system should make the app feel living, calm, and recognizably SoulBuddy without turning spiritual formation into a score or decorating every surface.

## Theological grammar

- **Vine:** Christ is the sustaining source. The vine must never imply that app activity produces grace.
- **Branches:** a person's lived journey with God. Branch length, fullness, or condition never ranks the person.
- **Leaves:** prayer, attention, and ordinary faithfulness.
- **Blossoms:** understanding and spiritual character taking shape.
- **Fruit:** love, obedience, service, and blessing carried outward.
- **Memorial marks:** promises, surrender, Scripture, encounters, and deeds of the Lord remembered.
- **Interwoven branches:** private Circles, family, and shared spiritual life.

The imagery is qualitative. Missing a day never withers a branch, completing actions never fills a progress tree, and the app never assigns spiritual value through points, streaks, ranks, or comparative abundance.

## Art direction

- Quiet editorial botanical forms with organic asymmetry and generous negative space.
- Warm ivory canvas, deep forest vine, sage leaves, restrained ochre fruit, muted blossom, and stone memorial tones.
- Gently tapered strokes and rounded leaves rather than cartoon plants, religious clip art, or photographic ornament.
- The existing olive-and-memorial illustration remains the richest hero image. The wider system uses lightweight code-native forms so screens remain fast and visually related.
- One focal botanical composition per screen state at most. Cards and controls remain readable UI, not literal leaves or fruit.

## Visual system

The code uses three token layers:

1. Primitive botanical colors and measurements.
2. Semantic roles such as `vine`, `leaf`, `blossom`, `fruit`, `memorial`, and `botanicalWash`.
3. Component roles for the living-line accent, section marker, and empty-state composition.

A reusable `LivingVine` component draws a low-contrast curved branch with a small, controlled set of leaves, buds, blossoms, fruit, or memorial markers. Variants communicate context rather than achievement. It is decorative by default and carries no duplicate accessibility semantics.

## Screen application

### Today

The branch quietly connects the day's three movements: Pray, Act, Remember. The existing signature illustration remains the new-user focal image. Selected-day content receives a restrained vine header rather than a dashboard or progress visualization.

### Prayers

A leafy vine accent introduces prayer as abiding and asking. The first screen remains easy to scan: the personalized-prayer invitation and filters stay subordinate to the library, and botanical elements do not wrap each prayer card.

### Remember

Memorial markers along a branch express deliberate remembrance. Recorded encounters remain searchable records; their number or density never changes the apparent health of the branch.

### Circles

Two gently interwoven branches express prayer and encouragement shared in private. The image does not imply public social status, audience size, or comparison.

## Motion and feedback

- Entry motion is a brief, subtle branch reveal or leaf unfurl.
- Meaningful completion may use a small leaf/blossom response instead of generic confetti.
- Reduced-motion environments render the final state immediately.
- Motion never blocks input, loops continuously, or signals spiritual achievement.

## Accessibility and responsive behavior

- Decorative botanical paths are excluded from semantics; meaningful surrounding copy remains the accessible explanation.
- Every visual remains secondary to text, controls, and focus order.
- Empty states keep their primary action visible without scrolling on the supported compact phone shell at normal text scale.
- At 200% text, decorative compositions reduce or yield space before content is compressed.
- Light and dark tokens maintain readable contrast; color is never the only carrier of meaning.

## Scope of the first slice

This slice establishes the tokens and reusable code-native primitive, then applies one restrained contextual composition to Today, Prayers, Remember, and Circles. It does not redesign every detail screen, generate a tree from user activity, add seasonal progression, or create new backend state.

