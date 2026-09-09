# Courses that become daily practice

Status: concrete product proposal based on the current app; the orientation reader is being implemented separately. The practice setup and additions described here are not yet shipped. Confession terminology awaits the user's clarification.

## Intended experience

The eight courses introduce a rhythm a person can carry into ordinary life: listen, choose one good action, pray, and reflect on what happened. The app should help someone become more attentive, truthful, generous, disciplined, and willing to return after a setback. Completing a recording is a learning event; doing a practical action is a separate event.

Use the user's preferred invitation throughout: **Plant something good in the garden each day.** The aspiration is **Aim for a plentiful harvest.** Show a single next step with room to change it. Keep the existing Today, Goals, Persons, Remember, and Circles destinations.

## A concrete example

After *The Lunch No One Saw*, the listener sees:

> **Plant something good today**
>
> Help one person with a practical need, without seeking recognition.
>
> About 5 minutes · From Seek God's heart
>
> **Make this my action** · Choose another · Maybe later

“Make this my action” opens a short, editable setup:

1. **My action:** Help my neighbour carry groceries. The person can change the words and choose a smaller step.
2. **For this Goal:** choose an existing Goal, or name a new one. Suggest an existing relevant Goal first; never silently create eight Goals.
3. **When:** Today, or choose a repeat schedule. Default to Today. Repetition is deliberate.
4. **Prayer, optional:** open the existing reviewed gratitude prayer, choose another reviewed prayer, or write/speak their own words. A saved prayer becomes a resource attached to that Goal.
5. **Remind me, optional:** use an existing Sacred Hour or set one. Explain that a Today action appears on Today; a reminder requires its own enabled schedule and device permission.

After saving: **“Your action is on Today.”** Show Open Today and Undo. Replaying the course offers **View my practice**; it never creates another copy automatically.

On Today, this is an ordinary Goal action with the existing Done, Skip, and Undo behavior. Afterward, an optional **Record what happened** prompt opens Remember: “Who benefited? What did you notice? What would you do differently?” Nothing is prefilled as a claimed outcome.

## Content for all eight courses

These action/reflection prompts are proposed editorial additions. Prayer titles below refer to existing reviewed content; they are not new generated prayers. Every action is editable, and the user chooses one rather than receiving an eight-item daily burden.

| Course / tenet | Default practical action | Smaller alternative | Existing prayer | Evening reflection |
|---|---|---|---|---|
| Welcome | Choose one practical act of kindness for today. | Name the person you could help. | For this day | What good seed did I choose today? |
| Pull the Weeds Early / Do not negotiate with sin | Remove one easy path back to a habit you have chosen to leave. | Name the trigger and one replacement action. | To ask forgiveness | What gave this habit an opening? What can I change tomorrow? |
| The Door Is Still Open / Hope in Christ's victory | Take one faithful next step you have been postponing. | Ask one trusted person for practical support. | In a difficult time | What helped me return after discouragement? |
| Make Room to Listen / Walk with the Holy Spirit | Pause for two quiet minutes before an important decision; pray, then consider what faithfulness asks of you. | Put the decision into one honest sentence before praying. | For guidance | Where did slowing down change my response? |
| The Song She Could Play / Discipline | Give one useful skill ten minutes of focused practice. | Prepare the materials for tomorrow's practice. | Before work | What became possible because I showed up? |
| More Than Her Name / Humility and service | Use one gift to meet a practical need for someone. | Ask what would actually help them. | For this day | Did I listen to the person's need, or choose what made me look good? |
| The Lunch No One Saw / Seek God's heart | Help someone without seeking recognition. | Offer your time or attention where money is not needed. | With gratitude | What did I give freely? Where am I still holding back? |
| What Did It Grow? / Bear fruit | Name one good result from today and choose one next step. | Remember one small act of patience, truthfulness, or kindness. | With gratitude | What changed in how I treated someone? What still needs care? |

For forgiveness, offer private prayer and reflection before any outward contact. The user can choose an appropriate act of repair; the app should not push reconciliation with someone unsafe. Existing behavior-specific Guards and Return flows remain the place for a difficult habit's support plan.

## Daily rhythm and recommendations

**Morning, 1–3 minutes:** a chosen Sacred Hour, a prayer, and the single action already selected for Today. An optional short reminder of the lesson's story helps recall the principle.

**During the day:** show the action when the user opens Today. Reuse existing reminder timing instead of adding a notification for every tenet. Notification text stays generic; private habits and reflections are visible only after opening the app.

**Evening, 1–2 minutes:** offer gratitude, honest reflection, and a next step. Saving words is optional. A missed action can be made smaller or tried on another day. No backlog of overdue spiritual duties.

**Occasional review:** invite the person to look at their own saved reflections and name something that changed. They can replay the related story, adjust the action, or stop a practice that is not helping.

Recommendation order is transparent and deterministic: the course the person explicitly selected; its compatible existing Goal; then a smaller alternative if requested. Show **“Suggested from the course you chose.”** Do not infer a person's sins or spiritual condition from journal text. Respect existing scheduled practices, avoid duplicate recommendations, and allow Hide this suggestion. Course order never locks practice access.

## Confessions: make the meaning explicit

The user's term may mean declarations of faith, acknowledgment of wrongdoing in prayer, or both. This is an open content decision, not an implementation default.

- **Declarations of faith:** provide deliberately reviewed wording with its source/provenance, clear meaning, and a link to the corresponding practice. Let the person speak their own words. Avoid promises that repeating a sentence guarantees an outcome.
- **Confession of wrongdoing in prayer:** offer a forgiveness prayer, optional private reflection, and a freely chosen act of repair. Use an unsaved reflection option. If saved, default this sensitive material out of automatic remembrance (`recallEnabled: false`); `sensitive: true` alone does not do that today.
- **Sacramental confession preparation, if wanted:** make it a separately named, opt-in experience requiring its own reviewed content. Do not present an app exercise as the sacrament.

No private confession text should enter reminders, recommendation ranking, analytics, testimonial prompts, or sharing without a separate explicit user decision.

## Improvements that would make the app feel connected

| Priority | Improvement | Why it matters |
|---|---|---|
| First | A Put this course into practice action in the reader and course library | Connects inspiration to a next step without making lesson completion mandatory. |
| First | One setup that reuses a Goal, its action, prayer, and optional Sacred Hour | Avoids a second habit tracker and lets Today remain the daily home. |
| First | Course origin and saved practice references, with duplicate protection | Repeated listening and retries cannot silently multiply tasks. |
| First | Goal detail lists its actions and linked prayers, with change/remove controls | Users can manage the practice after setup. |
| First | Correct Pray/Act/Remember indicators to include Goal-linked activity | A completed action must agree with Today guidance and visible status. |
| Next | Prompted Remember entry with course context and an optional voice response | Captures actual experiences in the person's own words. |
| Next | One optional end-of-week reflection in the existing Today guidance area | Makes change noticeable without another dashboard or spiritual score. |
| Later | Separate voice/music volume and a voice-only mix | Keeps the motivational delivery usable for people who find music distracting. |
| Later | A volunteered testimony draft with preview and explicit sharing consent | Supports trustworthy accounts of change without manufacturing praise. |

The current interactive reader already supplies the foundation for pace control, large text, synchronized highlighting, replay, and continuing later. Preserve those controls in practice transitions, save listening position before leaving, and return to the same course paused.

## Implementation grounded in the existing app

- `GoalRepository.create` / `addAction` and `GoalActionDraft` support today, daily, and selected-day actions. `completeAction`, `skipAction`, and `retractAction` remain the only completion history.
- `dueGoalActionsProvider` feeds `goalTodaySnapshotProvider` and `GoalTodaySections`. Add course origin metadata and durable references to existing Goal/action IDs; do not copy completion data into orientation storage. A transactional save or persistent idempotency key is necessary for partial-failure retries.
- `dailyPracticeStateProvider` currently projects the legacy Today prayer/action and daily remembrance. Extend its factual projection to Goal action events and linked prayer sessions, including the displayed local date, retractions, and deduplication. `watchDueActions` omits completed/skipped occurrences, so it cannot establish historical completion by itself.
- `reviewedEditorialPrayersProvider` and `watchApprovedPrayer` supply eligible prayer content. Use full stable IDs only after resolving review/publication state. Missing content offers another reviewed prayer or the person's own words. Existing prayer IDs have prefix `0198a100-0000-7000-8000-`: this day `000000000001`, gratitude `000000000002`, guidance `000000000003`, work `000000000006`, forgiveness `000000000007`, difficult time `000000000008`.
- `GoalLinkDraft.libraryPrayer` attaches the selected prayer. Prayer playback alone never marks a prayer session complete.
- Extract the existing Settings Sacred Hour editor launcher for reuse; keep its permission handling and reminder coordinator. Prefer changing a chosen existing hour to creating a duplicate morning/evening reminder.
- Extend `RecordScreen` with an initial memory type and course prompt. `EncounterRepository.create`, `MemoryType.lesson` / `MemoryType.testimony`, and `addReflection` already support the saved result.
- Existing destinations: `/goals/:goalId`, `/prayers/:prayerId`, `/prayers/create`, `/sacred-hours/:hourId`, `/remember/capture?mode=write`, `/remember/capture?mode=speak`, and `/remember/:memoryId`.

## Authentic evidence of value

Invite reflection on observable experiences: “I listened before responding,” “I made time for someone,” or “I asked for help.” These are example categories, not testimonials to publish. Ask open questions: What changed? What was difficult? What part helped? What should improve?

An account stays private until the author explicitly chooses to share it, reviews the exact text and audience, and consents. Public testimonial collection/publication needs a separate implemented consent and editorial flow; it does not exist in the current app. Never silently reuse private confession, prayer, or journal content as praise for SoulBuddy.

Evaluate the extension through usability and voluntary feedback: can someone make a lesson actionable without help; can they find and change that action later; do they understand reminders; do they find reflection useful; does the experience feel encouraging or burdensome? Do not label listen counts, completed tasks, or retention as measures of holiness or proof of spiritual transformation.

## Acceptance checks for the next implementation

1. Each course offers one relevant editable action, a prayer option, and a reflection prompt.
2. Listening completion never records prayer/action completion, and replay never adds a second practice.
3. Setup survives retry/relaunch without orphaned Goals, duplicate actions, or lost user edits.
4. Today, Goal detail, and Pray/Act/Remember agree after completion, skip, undo, midnight, and timezone changes.
5. The person can change or remove a practice and opt out of reminders; denial of notification permission does not block an action.
6. Prayer content remains reviewed or user-authored; unavailable reviewed content has an honest fallback.
7. Sensitive reflection is optional and excluded from automatic recall by default. No testimonial or public share is created automatically.
8. Onboarding can still be skipped, the reader preserves its place, and practice setup remains usable at large text sizes.

