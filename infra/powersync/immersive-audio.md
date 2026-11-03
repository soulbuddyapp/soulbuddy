# Private audio metadata: release check

Apply the [Laravel migration](../../services/api/database/migrations/2026_11_03_000000_add_audio_authoring_metadata.php) and deploy its sync handlers **before** updating the download configuration. The production rules are not in this repository. Use the active configuration from the instance's own deployment source. Keep the unmodified export as the baseline.

In the **existing private projections**, append these fields to the end of the explicit `SELECT` lists:

| Existing source table | Add to its list | Expected on download |
| --- | --- | --- |
| `personal_prayer_revisions` | `, content_format` | `audio` for a recorded prayer; `text` for an existing written revision. |
| `memory_reflections` | `, audio_encounter_id` | ID of the owned encounter containing the recorded reflection; null for a written reflection. |

Keep the existing table aliases, owner mapping, row predicates and authenticated bucket parameters. The commitment fragment is for different tables. Adding a second bucket or exposing an internal numeric user ID to the client is not part of this change.

## Compare the two exports offline

With Python 3 and PyYAML 6 (tested with 6.0.3), run from the repository root:

```sh
python infra/powersync/check_audio_projection.py active-rules.yaml candidate-rules.yaml
```

A zero exit means the parsed rules and export text match the baseline with exactly those two SQL-list additions. Keep comments and formatting unchanged for this check. It does **not** establish that the original authorization was correct. The checker does not connect to a service, write files or print configuration contents.

The automatic comparison supports legacy `bucket_definitions` with one existing direct query per target, explicit identifiers (including simple `AS` aliases), and an existing `WHERE user_id = bucket.<parameter>` or `WHERE owner_id = bucket.<parameter>` filter. It deliberately requests manual review for an already-present field, a missing or duplicate target, a wildcard target projection, SQL `%` patterns, complex target SQL, or Sync Streams. Preserve the original SQL spacing and SQL strings outside the two additions. For a view, trace the field through the existing view and rule; for a wildcard, determine what it already exposes after migration. Do not simplify a real predicate or convert a stream into a bucket to satisfy the checker.

## Acceptance on staging

1. Run the instance's configuration validator on the exact candidate. Verify the existing private parameters bind to the authenticated subject rather than a caller-supplied account. Record the matching baseline and candidate versions.
2. Use two synthetic identities, A and B. For each, create a recorded personal prayer and attach a voice reflection to a memory; keep the resulting revision, reflection and audio encounter IDs. Include one pre-migration written revision and one written reflection as compatibility controls.
3. After upload acknowledgement and the next completed download checkpoint, inspect a **fresh** sync client or the instance's authenticated diagnostics for each identity. Use supported staging authentication. The recording device's local reads alone cannot establish a successful download.
4. A must see A's exact revision with `content_format = 'audio'` and empty prayer body, and A's exact reflection with A's audio encounter ID. B must see its own corresponding rows. In each session, look up the other account's private IDs and require zero rows. The written controls must remain readable with the values in the table above.
5. On the fresh client, synced metadata must not yield playable private recordings from the other installation. On the original recording device, the original take must still play. Do not replicate local audio files, storage keys, or `voice_note_links`. Record pass/fail and synthetic IDs, never tokens or real prayer content.

Release the client only after these checks and the [device checks](../../docs/immersive-audio.md#verification). If validation fails, keep the client rollout on hold and restore the previous rules if necessary; keep the additive columns and recorded data.

[PowerSync parameter queries](https://docs.powersync.com/sync/rules/parameter-queries) · [Data queries](https://docs.powersync.com/sync/rules/data-queries)
