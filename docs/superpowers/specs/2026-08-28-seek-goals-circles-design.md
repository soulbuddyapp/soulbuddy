# SoulBuddy Seek, Goals, and External Circles Design

**Status:** Proposed product direction for implementation  
**Date:** 2026-08-28  
**Platforms:** Flutter iOS, Android, authenticated web; Laravel authoritative API; Telegram first-class external Circle provider

## 1. Product thesis

SoulBuddy should help a person seek God, act faithfully, guard what matters, walk with others, remember what happened, and return when they drift.

The governing Christian principle is Matthew 6:33: seek first the kingdom of God and his righteousness. SoulBuddy does not promise that prayer mechanically produces a preferred outcome. It helps a person bring real needs before God, ask for the Holy Spirit, order their life around what is good, take the next faithful action, remove avoidable occasions of failure, and remain accountable to others.

The product is not a prayer catalogue, an addiction programme, a life-coaching chatbot, or another social network. Prayer, Scripture, reminders, Voice Tablets, Altars, Record, Remember, practical boundaries and Circles are tools arranged around what the person is actually seeking.

## 2. Core vocabulary

Use ordinary words. Do not introduce branded programme language when a direct word is sufficient.

| Word | Meaning in SoulBuddy |
| --- | --- |
| **Seek** | The governing action: bring a real need before God and pursue what is right. Not a navigation tab. |
| **Goal** | Something the person is seeking help with. It may be actionable, mostly petition, or mixed. The distinction is internal and never presented as jargon. |
| **Today** | The small set of faithful things that need attention now. |
| **Return** | The immediate action when the person has drifted, fallen, or is being tempted. No reset-to-zero language. |
| **Record** | Preserve what happened, including a lapse, encounter, lesson, decision, promise or event. |
| **Remember** | Keep what should not be forgotten: Scripture, encounters, lessons, promises, people, Voice Tablets and Altars. |
| **Circle** | People walking together using Telegram or WhatsApp. SoulBuddy coordinates the purpose and rhythm; it does not host the chat. |

Primary navigation becomes:

`Today · Goals · Record · Remember · Circles`

The five destinations answer five ordinary questions:

- **Today:** What needs my attention now?
- **Goals:** What am I seeking?
- **Record:** What happened?
- **Remember:** What should I not forget?
- **Circles:** Who am I walking with?

## 3. Product invariants

### 3.1 God is central; the app is a tool

SoulBuddy may guide a person toward prayer, Scripture, repentance, practical obedience, counsel and accountability. It must not claim revelation, diagnose God's intent, or present itself as a spiritual authority.

### 3.2 No synthetic spiritual copy

User-facing spiritual language must come from one of three sources:

1. Scripture, with translation/reference provenance;
2. deliberately human-authored and reviewed SoulBuddy content;
3. the user's own words.

AI-generated prayers, exhortations, discussion prompts, pastoral answers, recovery encouragement, Scripture paraphrases or purpose statements are not permitted. Existing generated-prayer infrastructure is deprecated and must be removed after a safe migration path exists.

Software may retrieve, rank, filter and assemble approved human-authored fragments under deterministic rules, but it must never improvise spiritual prose.

### 3.3 No shame mechanics

No streaks, spiritual scores, relapse counters as identity, leaderboards, red failure states, or language implying that one lapse erased previous growth.

### 3.4 One app, not parallel programmes

Do not create separate Recovery, Freedom, Purpose, Coaching or Addiction navigation stacks. Goals configure existing SoulBuddy tools around a real need.

### 3.5 Local first for private spiritual material

Goal text, private prayers, boundaries, records and reflections must remain useful offline. Network access is required only for external Circle coordination, server-backed sync, directory discovery and other inherently remote functions.

### 3.6 Minimal disclosure

SoulBuddy does not need group chat history. External-provider events should be reduced to the minimum state needed to coordinate a Circle. Ordinary Telegram or WhatsApp conversation bodies must not be retained by SoulBuddy unless a future feature explicitly requires and justifies it.

## 4. First-use Goal experience

Replace the first-prayer-centric activation path with a guided first Goal. The user should finish onboarding with a useful Goal on Today, an appropriate prayer or Scripture resource, and at least one concrete next action when action is possible.

### 4.1 Entry question

**What would you like help with?**

Initial shortcuts:

- **Grow closer to God**
- **Stop something fighting to control me**
- **Find direction**
- **Get through a difficult time**
- **Something else**

These are entry shortcuts, not permanent taxonomy. The user's actual Goal title belongs to the user.

### 4.2 Common Goal wizard

Ask only questions that materially change the resulting Goal. Use one decision per screen and prefer choices over open-ended writing.

A common sequence is:

1. **What do you want help with?**
2. **What is happening now?** — concise choices plus optional Speak/Write.
3. **What can you do about this?** — `There are steps I can take` / `Mostly pray and wait` / `I'm not sure`.
4. **What would help today?** — select a small concrete action when appropriate.
5. **What do you need to guard against or remove?** — only when relevant.
6. **Who can walk with you?** — trusted person/Circle/not now.
7. **Bring this to God.** — choose an approved prayer, Scripture-led prayer form, or speak/write one's own words.
8. **Keep this on Today.**

The wizard must be resumable after process death and usable offline except where it intentionally opens an external provider.

### 4.3 Goal modes are internal

SoulBuddy may internally classify a Goal as:

- `actionable`: there are concrete steps the person can take;
- `petition`: the person mostly prays, waits, remains faithful and responds as circumstances change;
- `mixed`: both apply.

Never show these labels to the user.

Examples:

- `Stop watching pornography` → actionable/mixed.
- `Find direction in my work` → actionable/mixed.
- `Pray for Mum's recovery` → petition/mixed depending on caregiving responsibilities.
- `Forgive my brother` → actionable/mixed.

## 5. Goal model

A Goal is an organizing entity, not a replacement for prayers, encounters or reminders.

Conceptually:

```text
Goal
├── title
├── current situation / why it matters
├── status
├── prayer resources
├── Scripture resources
├── Today actions
├── guards / walls
├── reminders
├── trusted person / Circle links
├── records / encounters
└── periodic review
```

### 5.1 Reuse current SoulBuddy records

Do not duplicate mature primitives already present:

- `personal_prayers` remain prayers;
- `library_prayers` become an approved prayer resource catalogue rather than a primary destination;
- `prayer_reminders` continue to schedule prayer;
- `prayer_sessions` continue to record explicit prayer sessions without becoming a score;
- `voice_tablets` remain private user-authored audio resources;
- `encounters`, `memory_reflections`, Altars and remembrance remain unchanged in purpose;
- Today action/completion machinery should be generalized rather than rebuilt if its current model can safely carry Goal actions.

Goals connect these primitives through explicit link rows. Avoid nullable columns for every possible linked resource.

### 5.2 Goal lifecycle

Supported states:

- active;
- paused;
- completed;
- archived.

Completion must be reversible and non-celebratory. A Goal can remain in Remember after completion.

## 6. Today

Today is the operating surface of SoulBuddy.

It should not look like a project dashboard. It should show only what deserves attention now across active Goals.

Example:

```text
TODAY

Stop watching pornography
Pray
Phone outside bedroom by 10 PM
Check in tonight
[ Return ]  [ Open Circle ]

Find direction
James 1:5
Call Emmanuel about the course
30 minutes on the application

Pray for Mum
Prayer
Call her this evening
```

### 6.1 Today rules

- Show active Goals with due/relevant items, not every resource attached to every Goal.
- Prefer 1–3 meaningful items per Goal.
- Time-sensitive guards can rise before ordinary actions.
- A Goal with nothing due can remain absent from Today without appearing abandoned.
- No completion percentage or cumulative spiritual score.
- User controls ordering when multiple Goals compete for attention.

## 7. Return

`Return` is a direct action for Goals where drift, temptation or relapse is meaningful. It is not marketed as a programme.

For an addictive or compulsive behavior, a default Return sequence is:

1. **Move** — leave the place, device, account or circumstance giving immediate opportunity.
2. **Close the door** — activate the user's preselected barrier.
3. **Return to God** — open the chosen prayer, Scripture or Voice Tablet.
4. **Do the replacement** — perform a predetermined action incompatible with the behavior.
5. **Do not hide** — open the trusted person or Circle when configured.

The wording must remain short during temptation. Reflection happens later.

After the immediate danger passes, SoulBuddy may ask:

- What door was still open?
- What time/place/state made this easier?
- What wall should change before next time?

The user can Record the answer. A lapse never resets the Goal to day zero.

## 8. Guards and walls

SoulBuddy should help the person reduce avoidable access to what they are trying to stop.

A guard is a concrete protection attached to a Goal. Examples:

- filtered DNS on a phone or PC;
- SafeSearch/content restrictions;
- Screen Time / Family Link / OS-level restrictions;
- deleting or restricting an app;
- removing gambling accounts or using operator self-exclusion;
- moving a phone outside the bedroom;
- giving a restriction PIN to a trusted person;
- removing stored payment methods;
- avoiding a vulnerable place or time;
- keeping a predetermined replacement activity ready.

### 8.1 Device guidance

Guidance must be device-specific and factual. Where DNS is useful, support several reputable options instead of making SoulBuddy dependent on one vendor, for example AdGuard Family Protection, CleanBrowsing Family Filter and user-configured NextDNS profiles.

SoulBuddy should record that the user says a wall is configured; it must not claim technical enforcement it cannot independently verify.

### 8.2 Gambling

Where available, prioritize operator/regulator self-exclusion and binding money/time limits. WHO specifically recommends effective self-exclusion and pre-commitment as harm-reduction tools. Do not reduce gambling support to willpower prompts.

Reference: https://www.who.int/news-room/fact-sheets/detail/gambling

### 8.3 Tobacco/nicotine

SoulBuddy can support prayer, motivation, triggers, reminders, accountability and behavioral plans, but must not imply that the app is a substitute for evidence-based cessation treatment. WHO recommends behavioral support, digital interventions as adjunct/self-management tools, and effective cessation medication where appropriate.

References:

- https://www.who.int/publications/i/item/9789240096431
- https://www.who.int/news/item/02-07-2024-who-releases-first-ever-clinical-treatment-guideline-for-tobacco-cessation-in-adults

### 8.4 Alcohol

The app must not instruct a person with possible physiological dependence to abruptly stop without medical guidance. The alcohol Goal starter requires a safety screen that identifies warning signs/history that warrant urgent professional assessment before a quit plan. SoulBuddy may continue to support prayer, motivation, boundaries and accountability around professional care.

### 8.5 Pornography / sexual compulsion

Use concrete language such as `Stop watching pornography` when that is the user's stated Goal. Do not label every user with a medical addiction diagnosis. Useful guards include content filtering, device restrictions, bedroom/device boundaries, removal of alternate access routes, replacement behavior and accountability.

### 8.6 Digital distraction

Compulsive phone/social use can be supported as a behavior Goal without presenting a clinical diagnosis. Typical guards include notification reduction, removing high-friction apps from the home screen/device, scheduled access, bedtime boundaries and focus modes.

## 9. Find direction

SoulBuddy must not tell a person what God's secret purpose for their life is.

The direction path helps a person seek, become quiet, pray, examine responsibilities, discern, act, and observe what follows.

Suggested prompts:

- What feels stuck?
- What are you waiting for?
- What responsibility is already in front of you?
- Is there something you know you should do but keep postponing?
- What ability or concern keeps recurring?
- Who is affected by this decision?
- What can you faithfully do in the next 24 hours?

The output is a Goal with one small next action, not a generated destiny statement.

The existing Record/Remember system is particularly valuable here: later reviews can surface the user's own remembered encounters, lessons, commitments and patterns without inventing spiritual interpretations.

## 10. Prayer becomes a Goal resource

The current Prayers destination should be replaced by Goals in primary navigation.

The prayer library remains available as a resource picker and secondary browsing surface, but a new user should not need to understand prayer taxonomy before SoulBuddy understands what they are seeking.

Prayer choices should be contextual:

- prepared human-authored prayers associated with the Goal context;
- Scripture-led prayer forms;
- the user's own spoken/written prayer;
- saved personal prayers already linked to related records.

Remove user-facing generated prayer drafts. Existing DeepSeek prayer-generation request/attempt infrastructure should be retired after migration and tests prove no accepted personal prayer or user data is lost.

## 11. Circles: discovery and creation

Circles become a discovery/create destination rather than an in-app chat list.

Top-level discovery sections:

1. **Accountability** — people helping one another remain answerable while pursuing a Goal.
2. **Daily Exhortation** — scheduled Scripture and concise, human-authored encouragement.
3. **Bible Study** — read, discuss and apply Scripture together.

The empty/landing surface should support both discovery and creation:

```text
CIRCLES

Find people to walk with.

Accountability
Daily Exhortation
Bible Study

[ Create a Circle ]
```

### 11.1 Directory cards

Show only useful metadata:

- Circle name;
- category;
- provider (`Telegram` / `WhatsApp`);
- concise purpose;
- member count when reliably available;
- public/invite-only state;
- join action.

Do not preview chat content in SoulBuddy.

### 11.2 Visibility

Support:

- public/discoverable;
- unlisted/invite-link only;
- private/owner-managed.

Discovery requires a server-authoritative directory and moderation state. A provider group existing externally does not automatically make it discoverable in SoulBuddy.

## 12. External Circle providers

### 12.1 Provider contract

Model provider capabilities explicitly. Do not pretend Telegram and WhatsApp support the same operations.

A provider may expose capabilities such as:

- open/join link;
- bot binding;
- scheduled outbound message;
- inline/check-in action;
- member count;
- pin message;
- manage discussion topics;
- create provider group;
- receive membership events.

UI appears only for supported and verified capabilities.

### 12.2 Telegram: first-class automated provider

Telegram is the first automated Circle provider.

Official Telegram bot deep links support `startgroup`, allowing SoulBuddy to carry a short signed binding token while the owner chooses a group to add the bot to. Bots run in Privacy Mode by default and only receive relevant commands/service messages unless made admins or privacy mode is changed.

References:

- https://core.telegram.org/bots/features
- https://core.telegram.org/api/links
- https://core.telegram.org/api/forum

Recommended flow:

1. user creates Circle in SoulBuddy;
2. chooses Telegram;
3. SoulBuddy generates a short-lived signed binding token;
4. opens `t.me/<bot>?startgroup=<token>`;
5. user selects a Telegram group;
6. bot receives the binding event and server validates token/user/Circle;
7. SoulBuddy stores only provider identifiers and capabilities needed for coordination;
8. Circle page becomes the control surface for schedules/topic/accountability;
9. `Open Circle` deep-links to Telegram.

Request minimum bot permissions. Sending scheduled messages needs ordinary posting ability. Pinning or Telegram forum-topic management requires elevated rights and must be optional. If the bot is an admin and therefore receives broad group traffic, SoulBuddy must discard ordinary message bodies that are irrelevant to a configured feature.

### 12.3 WhatsApp: capability-gated provider

Do not assume SoulBuddy can add a general-purpose bot to any existing WhatsApp group in the same way as Telegram.

Meta's WhatsApp Business Platform has Groups API support, but eligibility and group behavior are account/capability dependent and may change. Current official/Meta-hosted documentation confirms Cloud API business messaging; Groups API access must be verified against the production business account before automation is enabled.

References:

- https://www.postman.com/meta/whatsapp-business-platform/overview/
- https://developers.facebook.com/documentation/business-messaging/whatsapp/groups

Initial provider modes:

- `whatsapp_link`: SoulBuddy stores and opens a user-supplied WhatsApp group invite link; Circle schedules can still trigger local creator reminders, but SoulBuddy does not claim bot delivery.
- `whatsapp_groups_api`: enabled only after a startup/server capability probe and staging verification prove the business account can create/manage/send to groups.

This lets WhatsApp appear in the product without making an unavailable automation path a launch dependency.

## 13. Circle configuration

The Circle detail page is configuration, not conversation.

Example:

```text
MEN WALKING IN PURITY
Accountability · Telegram

[ Open Circle ]

Purpose
Pornography and sexual discipline

Check-in
Every day · 9 PM

Exhortation
Every morning · 7 AM

Bible focus
Romans 6 this week

Members
12

Edit rhythm
Change topic
Invite people
Pause Circle
```

### 13.1 Accountability check-ins

Prefer private responses where possible.

A group can receive:

`Evening check-in — open SoulBuddy / check in with the bot.`

Possible private response choices:

- `Kept it`
- `Struggled`
- `Need prayer`

Do not publicly post a member's struggle status by default. Optional aggregate counts may be enabled only if privacy review approves them.

### 13.2 Daily exhortation

Every exhortation is human-authored/reviewed and linked to its Scripture/context source. Keep it concise. The scheduler chooses from an approved content plan; it does not generate text.

### 13.3 Bible study

A study plan contains a sequence of Scripture passages, one or more reviewed questions, schedule and optional provider topic/pin settings.

Example content shape:

- passage: `Matthew 6:19–34`;
- question: `What does Jesus tell us to seek first?`;
- optional action: `Name one thing competing for first place this week.`

## 14. Goal ↔ Circle relationship

A Goal can link to zero or more Circles, but one Circle should usually be the primary accountability Circle for that Goal.

Examples:

- `Stop watching pornography` → `Men Walking in Purity` accountability Circle;
- `Find direction` → a discernment/accountability Circle;
- `Grow closer to God` → daily exhortation or Bible study Circle.

Today may show `Open Circle` or a due check-in under the Goal. It must not duplicate the external conversation.

## 15. Content architecture

Create a versioned editorial content catalogue with provenance and review state.

Content kinds include:

- prepared prayer;
- prayer frame/template;
- exhortation;
- discussion question;
- Goal starter copy;
- guard/wall instruction;
- Return instruction;
- safety notice;
- Bible study plan.

Each published item should have at least:

- stable ID;
- kind;
- title/short label where needed;
- body;
- source/provenance fields;
- theological/editorial review state;
- applicable Goal starter/tags;
- version;
- published/archived timestamps.

No content-generation provider is required for runtime operation.

## 16. Privacy and moderation

### 16.1 Private Goals

Goal title, current situation, prayer text, guards, lapse reflections and private records remain private to the user unless they explicitly choose to share a specific representation.

### 16.2 Circle directory

SoulBuddy owns directory metadata and moderation, not provider conversation content. Public Circle discovery requires:

- owner identity/accountability;
- category and description review capability;
- report Circle action;
- delist/suspend capability;
- abuse/risk audit trail without storing unrelated group conversations.

### 16.3 Provider tokens

Bot/API secrets never reach Flutter. Provider callbacks are verified server-side. Binding tokens are short-lived, single-use and contain no private Goal text.

## 17. Product analytics without private content

Analytics may record structural events such as:

- onboarding completed;
- Goal created/paused/completed;
- Return opened/completed;
- guard marked configured;
- Circle discovery viewed;
- provider handoff started/completed;
- Circle schedule configured.

Never log Goal titles, prayer bodies, Scripture excerpts, lapse text, voice content, Circle chat messages, private check-in state or provider tokens.

## 18. Migration from the current app

### 18.1 Preserve mature features

The redesign is an orchestration migration, not a rewrite.

Keep:

- Today storage and rendering primitives that remain useful;
- prayer library and saved prayer records;
- prayer reminders and sessions;
- Voice Tablets;
- Altars and altar rituals;
- Record/Remember/Scripture;
- local identity and sync infrastructure;
- feedback/accessibility systems.

### 18.2 Replace primary prayer IA

- `/prayers` stops being a primary shell destination.
- `/goals` becomes the second shell destination.
- prayer detail routes remain addressable as resources.
- first-prayer onboarding migrates to first-Goal onboarding while reusing its durable progress, Speak/Write and fallback patterns.

### 18.3 Retire generated prayer infrastructure

Stop creating new `prayer_generation_requests`. Provide deterministic approved-content selection and own-words paths. Preserve already accepted `personal_prayers`. Remove provider code/config only after migration tests and data audit pass.

### 18.4 Retire in-app Circle chat

Current local-only `circles`, `circle_members` and `circle_messages` were intentionally device-local. Do not migrate their messages into the external provider automatically. Existing local Circle content is private user data and must be handled explicitly:

- allow export/copy before removal; or
- convert meaningful local messages to private Record entries only with explicit user action.

New Circle schema stores directory/config/provider binding, not replicated chat history.

## 19. Performance and reliability budgets

- Today must remain usable from local storage without network.
- Creating/updating a Goal should visibly commit locally within the existing local-first mutation budget.
- Return must open without network and expose all locally available steps immediately.
- Provider handoff failure must leave the Circle draft intact.
- Scheduled Telegram delivery must be idempotent and deduplicated by `(circle_schedule_id, occurrence_key)`.
- Webhook retries must not duplicate bot posts or check-in events.
- Provider outage must not block Goals, Today, Record or Remember.

## 20. Accessibility

- One decision per wizard step where practical.
- Speak and Write remain equal alternatives.
- 48dp minimum interactive targets.
- 200% text scaling without clipped primary actions.
- External-provider handoffs clearly announce that the user is leaving SoulBuddy.
- Circle provider is never communicated by color alone.
- Return remains usable with reduced motion and screen reader.

## 21. Explicit non-goals

- No in-app group messaging.
- No public social feed.
- No AI-generated prayers, sermons, exhortations, Bible-study questions, spiritual direction or recovery copy.
- No claim to diagnose addiction or mental illness.
- No claim that prayer alone replaces medical treatment.
- No spiritual score, relapse score or holiness metric.
- No bot that impersonates a pastor or speaks as God.
- No ingestion/storage of ordinary external group conversations for analytics.
- No requirement that every Goal has a Circle.

## 22. Acceptance summary

This redesign is successful when a new person can state what they need help with, create a Goal through a short guided path, see the relevant prayer/Scripture/action/guard/accountability items on Today, use Return without shame when they drift, and attach an external Circle without SoulBuddy becoming a messaging product.

Circles are successful when a person can discover or create Accountability, Daily Exhortation or Bible Study Circles; Telegram-based Circles can be bot-bound and scheduled from SoulBuddy; WhatsApp behavior is capability-gated and honest; and all scheduled spiritual content is Scripture, human-authored/reviewed content or the user's own words.
