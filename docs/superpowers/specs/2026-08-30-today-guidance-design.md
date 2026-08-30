# SoulBuddy Today Guidance Design

**Status:** Approved for implementation

**Date:** 2026-08-30

**Platforms:** Flutter mobile/web; local-first activity projection

## Purpose

Today must not end with **No practices available today**. When no routine is shown—or when another feature can meaningfully help—the screen should offer one truthful, relevant next step. When the person has attended to what is due, it should offer concise, reviewed encouragement.

This is deterministic feature guidance, not generated spiritual coaching. Every displayed claim comes from local application state, and every spiritual sentence is deliberately authored and reviewed.

## Terminology and factual scope

A daily practice becomes available from an actual due or selected item, including:

- a prayer selected for Today;
- a practical action attached to that prayer or an active Goal;
- a scheduled remembrance;
- a due Person prayer;
- a due Altar ritual where the existing Today integration supports it.

Joining or owning a Circle does not itself create a completed practice. Circle guidance may be recommended as accountability when factual recent history shows repeated misses.

## Guidance snapshot

Create a `TodayGuidanceSnapshot` that contains only facts needed for guidance:

- whether Goals, prayers, memories, Persons, Altars, and Circles have ever been used;
- due and completed routines for the displayed local day;
- the count of genuinely scheduled routines missed during the previous seven completed local days;
- the highest-priority due destination and its route;
- whether all due routines are complete.

A missed routine is counted only when a stored schedule made it due on a completed local day and no matching completion exists. The engine must not infer a miss from an unused feature, an unscheduled Goal, a disabled reminder, lack of network access, or absence from a Circle.

## Guidance engine

`TodayGuidanceEngine` is a pure deterministic component. It returns at most one reviewed card model containing message key, icon kind, title/body, action label, and internal route.

Priority order:

1. A due routine that can still be completed today.
2. Repeated missed routines with no joined Circle.
3. The highest-value core feature the person has not explored.
4. Completion encouragement when all due routines are complete.
5. A quiet return invitation when features exist but nothing is currently due.

Repeated-miss accountability appears only when at least two scheduled routines were missed during the previous seven completed local days and the person is not in a Circle:

**A Circle could help**

**You missed two planned routines this week. A Circle can help you stay accountable.**

Action: **Explore Circles**

The displayed number must match the snapshot. Counts above three may use **several** to avoid turning the message into a score.

Example unexplored-feature messages include:

- **Begin with prayer** — Choose a prayer to keep close today.
- **Keep what happened** — Record an encounter, promise, Scripture, person, or lesson before it is forgotten.
- **Remember someone in prayer** — Add a person you want to pray for faithfully.
- **Name what you are seeking** — Start a Goal and keep the next faithful action on Today.

Example completion encouragement:

**Remain close**

**You kept today's routines. Give glory to God and remain close to Him.**

Encouragement must never claim spiritual maturity, divine approval, protection from temptation, guaranteed growth, or that the app caused the result.

## Presentation

Remove visible **No practices available today** copy. Keep accurate screen-reader semantics such as **No daily routines are set** when applicable.

Place one compact guidance card immediately beneath the covenant slabs. It contains:

- one restrained icon or covenant-grace mark;
- a short title;
- no more than two short lines of body copy at normal text scale;
- at most one primary action.

At standard phone size and text scale, the slabs, guidance card, and primary action must fit without required scrolling when Today otherwise has no content. At large text sizes, scrolling is allowed so content is never clipped. Motion and haptics follow existing preferences and reduced-motion settings; merely displaying guidance does not trigger celebratory feedback.

## State transitions

Guidance recomputes when a relevant repository emits new state. Completing a routine replaces its prompt with the next eligible guidance without requiring an app restart. Adding a Goal, prayer, memory, Person, Altar, or Circle removes the corresponding unexplored-feature suggestion.

The engine uses stable priority and message keys so rebuilds do not rotate copy unexpectedly. This slice does not add dismissals, random tips, generative copy, or a recommendation history table.

## Error handling and privacy

If history or one feature repository is unavailable, the engine omits claims dependent on it and selects a lower-risk factual message. It never converts a loading or sync error into a missed routine.

No private titles, prayer bodies, person names, memory content, or Goal descriptions appear in analytics. Structural message-key impressions and action taps may be measured locally or through privacy-safe analytics.

## Acceptance criteria

1. **No practices available today** is absent from visible UI.
2. Empty Today shows one useful, actionable, state-aware card.
3. A feature already used is not recommended as unexplored.
4. Missed-routine wording appears only from verified scheduled history and uses the correct count.
5. Circle guidance appears only when the miss threshold is met and no Circle is joined.
6. Completion encouragement appears only when at least one routine was due and all due routines are complete.
7. The empty state fits a standard small phone without required scrolling and remains accessible at 200% text.
8. No AI-generated spiritual copy or fabricated activity claim is possible.
