# SoulBuddy Goal Action Guidance Design

**Status:** Approved for implementation

**Date:** 2026-08-30

**Platforms:** Flutter mobile/web; authenticated Laravel API; offline local fallback

## Purpose

The first Goal guide should help a person name why a Goal matters and identify one useful action without pretending to know God's will. The guide may use the person's own explanation to suggest ordinary, concrete actions. It must not generate prayer, Scripture, exhortation, prophecy, spiritual interpretation, or language presented as divine guidance.

## First Goal flow

After the person chooses a starter such as **Grow closer to God**, the situation step becomes:

**Why now? What needs to change?**

The optional choices remain:

- **Speak**
- **Write**
- **Not now**

Speak uses the existing on-device speech-recognition path and places the recognized words in an editable text field. Raw onboarding audio is not uploaded. The person can review the text before continuing.

The next question remains:

**What can you do about this?**

- **There are steps I can take**
- **Mostly pray and wait**
- **I'm not sure**

At **What would help today?**, SoulBuddy displays up to three short action suggestions. When the person chose **I'm not sure**, suggestions load automatically. For the other choices, the normal text field remains primary and a secondary **Suggest ideas** action is available.

The person can:

- choose one suggestion;
- ask for another set;
- write their own action;
- continue without an action.

Only the selected or personally written action is saved with the Goal. Rejected suggestions are not stored.

## Suggestion service boundary

Create a narrowly scoped authenticated server endpoint for practical Goal-action suggestions. The request contains only:

- the starter key;
- the Goal title;
- the optional reviewed situation text;
- the agency choice;
- the interface locale.

The server validates lengths, rate-limits requests, and returns no more than three suggestions. Each suggestion must be concise, concrete, safe, possible within the near term, and phrased as an option rather than a command.

The service must reject or avoid:

- prayer text or spiritual exhortation;
- claims about what God wants, said, revealed, or will do;
- Scripture quotation or paraphrase;
- diagnosis or treatment instructions;
- dangerous withdrawal, self-harm, violence, abuse, or emergency advice;
- shame, spiritual scoring, and guarantees of outcomes.

Existing alcohol safety gates remain authoritative. An action suggestion cannot bypass them.

The runtime provider stays an infrastructure detail and is never named in the app. Request and response bodies must not be written to application logs or analytics. Structural success/failure metrics may be recorded without private text.

## Offline and failure behavior

The Flutter application owns a reviewed, deterministic fallback catalogue keyed by Goal starter and selected behavior. If the service is offline, times out, returns invalid material, or is unavailable on web, the same suggestion surface displays locally reviewed options without exposing a technical error.

If neither remote nor fallback suggestions are available, the person can still write or skip. The Goal flow must remain resumable and local-first.

## Components

- `GoalActionSuggestionRequest` and `GoalActionSuggestion`: provider-neutral domain values.
- `GoalActionSuggestionRepository`: Flutter interface with server and local-fallback composition.
- `GoalActionSuggestionService`: server boundary responsible for provider calls, validation, and safe response normalization.
- `GoalActionSuggestionPanel`: compact choice UI inside the existing Today-action step.
- Existing `GoalOnboardingProgress.currentSituation`: retained as the reviewed text used for suggestions.

The suggestion UI must not be embedded directly into the flow state machine. The state machine continues to own navigation and the final selected action; the repository owns suggestion retrieval.

## Accessibility and performance

- Suggestions use ordinary buttons/cards with 48dp minimum targets.
- Loading does not block access to writing or skipping.
- The screen remains usable at 200% text scaling.
- A cached fallback should appear immediately; a remote result may replace it only before the person has begun editing or selected an option.
- One failed provider call must not restart or discard Goal onboarding progress.

## Acceptance criteria

1. Every situation entry surface uses **Why now? What needs to change?**.
2. Spoken words become editable text and can inform suggestions.
3. **I'm not sure** automatically produces useful choices without blocking the user.
4. Other agency choices can request suggestions without losing the manual path.
5. Offline use produces reviewed local suggestions.
6. No generated prayer, Scripture, spiritual direction, medical treatment, or provider branding reaches the UI.
7. Only the chosen action is persisted.
