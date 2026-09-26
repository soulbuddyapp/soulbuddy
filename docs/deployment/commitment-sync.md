# Commitment replication

The Flutter connector obtains a signed token from Laravel `/api/sync/token`,
then downloads through the configured PowerSync endpoint. Uploads use the existing
authenticated `/api/sync/mutations` endpoint. No additional download API is needed.

The JWT subject and Flutter `owner_id` are `users.public_id`. The six Commitment
tables contain both the internal numeric `user_id` and an `owner_id` UUID derived
by the writer from the authenticated user. A composite foreign key enforces that
these identify the same user. Client ownership fields never select the server owner.

Merge `infra/powersync/commitments.sync-rules.yaml` into the existing PowerSync
configuration after applying the Laravel migrations. Preserve existing Goal,
Goal action, revision, and prayer buckets: finalization uploads those records in
the same atomic transaction. The fragment requires replication of `users` and
the six Commitment tables. It uses a signed-subject parameter query; deleting
the user removes bucket eligibility. Explicit data columns exclude internal IDs
and future unreviewed fields. This follows PowerSync's
[parameter query](https://docs.powersync.com/sync/rules/parameter-queries) and
[data query](https://docs.powersync.com/sync/rules/data-queries) contracts.

This fragment targets an existing Sync Rules deployment. For an instance already
using Sync Streams, translate it through the service's supported migration path;
do not replace an existing stream configuration with this legacy fragment.
PowerSync now labels Sync Rules as legacy in the linked documentation.

Before publishing the configuration, run the PowerSync instance's rules validator
and test two authenticated accounts against a nonproduction replica. Verify that
each receives only its own six-table graph, that `owner_id` equals its JWT subject,
and that replaying a complete finalization creates no extra rows. The local PHP
test executes every fragment data projection for two owners; it does not simulate
the PowerSync replication engine or validate remote service configuration.

Never include journey progress, practice drafts, reminder devices, recovery
markers, or personal-prayer narration cache tables in replication. Those records
are device-local. Keep service credentials and JWT signing keys in the existing
protected deployment environment. This change does not deploy or rotate them.
