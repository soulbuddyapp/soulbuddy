# SoulBuddy Remember and Persons Design

**Status:** Approved for implementation

**Date:** 2026-08-30

**Platforms:** Flutter mobile/web; PowerSync local-first storage; Laravel authoritative sync API

## Purpose

SoulBuddy should have one obvious place for preserving and revisiting what must not be forgotten. **Remember** therefore owns both capture and recall. The vacated primary destination becomes **Persons**, a private place to keep people the user wants to remember in prayer.

Primary navigation becomes:

`Today · Goals · Persons · Remember · Circles`

## Remember owns capture

Remove Record as a primary shell destination. Remember begins with two persistent capture choices:

- **Speak**
- **Write**

Both paths continue to support Encounter, Promise, What I left behind, Revelation, Scripture, Person, Family, Lesson, and Testimony. Existing `/record` links and notification destinations redirect to the equivalent Remember capture route so bookmarks and older app state do not break.

The written encounter form labels its main detail field **What happened? (optional)** and always places a microphone action beside or directly beneath it. A person may:

- write only;
- record audio only;
- write and attach audio;
- replace or remove the recording before saving.

The existing private memory-audio storage remains local-only. Adding voice inside the form must reuse the current capture controller, durable asset store, playback, deletion, and cleanup behavior rather than create a second recorder.

## “We forget quickly” invitation

Remember displays a reviewed reflection card:

**We forget quickly**

Expanded body:

> Miracles and mercies meet us every day—God's quiet reminders that He loves and cares for us. Yet we forget quickly. Think of the last time you said, “Wow,” “Thank God,” or “I'm grateful, Lord.” Do you still remember what He did? Make remembering a habit.

Before the first memory is saved, the card is expanded and cannot be collapsed. Speak and Write remain visible in the normal first phone viewport without required scrolling at standard text size. After the first memory, the card starts collapsed with the single-line preview:

**Remember the moments that made you say, “Thank God.”**

The user may expand or collapse it thereafter. The expanded state is presentation state, not synced spiritual data.

## Persons

The Persons destination answers: **Who do I want to remember in prayer?**

Each private person record contains:

- stable ID and owner ID;
- name, required;
- relationship, optional, selected from common choices or entered in the user's own words;
- cadence: daily, weekly, or selected weekdays;
- selected weekdays when applicable;
- optional local prayer time and timezone;
- active/archived state;
- created and updated timestamps.

Do not add a general notes field, contact-book import, phone number, address, birthday, social profile, or public directory in this slice.

The Persons empty state shows one compact invitation and **Add someone**. A person card shows the name, relationship when present, and the next prayer rhythm in plain language. The detail screen supports edit, archive, **I prayed for them**, and **Remember something about them**.

## Person prayer occurrences

Record explicit person-prayer occurrences so reminders and Today can distinguish due from completed. An occurrence contains the person ID, owner ID, local date, completion timestamp, device ID, and an idempotency key. It is not a streak and is never used to score the user or the person.

If a prayer time is configured, schedule a local notification through the existing reminder infrastructure. Opening it goes to the person's private detail surface. The notification offers the existing lightweight acknowledgement pattern where the platform permits it. A missed notification must not be described as sin, failure, or neglect.

## Connecting Persons and Remember

An encounter can link to zero or more saved Persons through an owner-scoped join table. The capture flow presents an optional **Who was part of this?** picker after the memory type is chosen or within the form. A Person detail screen lists linked memories and opens the normal memory detail screen.

Selecting **Remember something about them** opens Remember capture with that person already selected. The memory type defaults to Person but remains editable.

The existing `MemoryType.person` remains a content classification. A typed Person memory is not automatically converted into a Persons directory record; linking is always explicit so sync cannot silently create duplicate people.

## Storage and sync

Add owner-scoped PowerSync/Laravel tables for:

- `prayer_people`;
- `person_prayer_occurrences`;
- `encounter_person_links`.

Mutations follow the existing installation identity, optimistic local write, idempotency, and owner-integrity patterns. Parent deletes/archive rules must preserve private memory integrity:

- archiving a person hides schedules but preserves occurrences and memory links;
- deleting an encounter removes only its join links;
- a client cannot link an encounter or occurrence owned by another account.

Person names, relationships, schedules, linked memory content, and prayer occurrence details must not enter analytics logs.

## Error handling

- A local save failure keeps entered fields and recordings available for retry.
- Notification permission denial saves the person and cadence, then explains that timed reminders require permission.
- An invalid or unavailable timezone falls back to the device timezone and remains editable.
- Archive and completion actions are idempotent.
- Old `/record` routes never show a missing-page error.

## Acceptance criteria

1. The shell reads `Today · Goals · Persons · Remember · Circles` on phone and wide layouts.
2. Remember supports Speak and Write without visiting another primary tab.
3. **What happened?** always offers voice capture, including after the user began writing.
4. The first-memory reflection is expanded until one memory exists and compact thereafter.
5. A person can be added, scheduled, edited, archived, and marked prayed for while offline.
6. A configured time creates a local reminder and opens the correct person.
7. One or more Persons can be linked to a memory without changing its type.
8. Existing `/record` entry points redirect safely.
