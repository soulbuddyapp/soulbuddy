# Guided Onboarding and Circles Design

## Purpose

Make SoulBuddy immediately understandable to a new user without turning spiritual practice into a dashboard, score, or cosmetic exercise. Today should offer a gentle starting path, Prayers should reveal complexity only when requested, and Circles should become a truthful, useful private-space experience rather than a placeholder.

## Experience principles

- SoulBuddy remains a humble aid to prayer, action, and remembrance.
- Each first-use surface has one clear primary action.
- Guidance uses concrete options and minimal wording, not vague reflection prompts.
- Graphics use Material symbols, layered semantic-color surfaces, and quiet botanical/radiating forms rather than stock illustrations or emoji.
- Private records are never shared implicitly. Sharing always creates a deliberate snapshot.
- No streaks, scores, leaderboards, competitive counts, or celebratory confetti on empty states.

## Today

When neither a prayer nor a daily remembrance is available, Today presents one compact composed guide rather than two isolated buttons. Its framework-grounded invitation connects prayer with attention to God, surrender, and faithful action. “Choose a prayer” is the primary action and “Record something to remember” is secondary. The entire empty state and both actions fit the initial normal-text viewport without scrolling. Once either item exists, the guide yields to the real content so daily use remains quiet.

## Prayers

The first view describes prayer as communion and invites the user to turn toward God, surrender desire, and carry faith into action. It makes no unsubstantiated claims about community helpfulness or ranking. “Create personalized” stays visible as a secondary route. Grounding and purpose filters move behind a labelled, accessible disclosure control. The control summarizes active choices and preserves filter state. This retains the full library while reducing first-use overload.

## Circles

Circles are private and invitation-only. The first usable slice supports:

- creating a named private Circle locally;
- seeing Circle membership and privacy guidance;
- opening a durable local conversation;
- sending text messages offline;
- seeing explicit placeholders for invitation and structured sharing actions that require the authenticated server boundary.

The empty state uses only a compact private-by-design and deliberate-sharing explanation, with the creation action visible without scrolling at normal text size. The screen must not imply that local-only members have received messages or invitations. Cross-device invitations, roles, moderation, reactions, and shared snapshots remain part of the existing MVP specification and must be implemented with the server authorization boundary before those controls become active.

## Accessibility and responsiveness

All actions use native Material controls with at least 48dp targets. Content remains scrollable at 200% text scale and adapts from phone to tablet without horizontal page scrolling. Graphics are decorative where copy already conveys their meaning; functional icons receive semantic labels or tooltips. Light and dark themes use existing semantic tokens.

## Verification

- Widget tests prove Today’s guide actions and progressive disappearance.
- Widget tests prove collapsed and expanded Prayer filters, active-filter summary, and no-result recovery.
- Real PowerSync tests prove Circle and message persistence across repository reopen and owner scoping.
- Widget tests prove Circle creation, conversation, offline send, loading/error/empty states, and large-text layout.
- Full Flutter analysis/tests, Android build, installation, and physical-device launch complete before merge.
