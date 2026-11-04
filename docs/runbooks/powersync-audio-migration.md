# PowerSync audio migration rehearsal

The existing SoulBuddy production database is MariaDB 10.3 without binary
logging. PowerSync's MySQL connector requires a supported MySQL source with
row-based binary logs. Do not point the connector at the existing database or
replace the production database with the rehearsal instance.

## Rehearsal, 2026-11-03

- A private, network-isolated MySQL 8 instance was populated from a production
  snapshot. Existing triggers were restored under a valid rehearsal definer.
- The audio metadata and ownership projection migrations ran against a second
  fresh snapshot. Aggregate fingerprints for the original columns of all 66
  application tables matched before and after migration, including automatic
  timestamps. Migration bookkeeping was excluded from the comparison.
- A separate synthetic 31-table test checked backfill, automatic timestamps,
  forged-owner writes, immutable public account IDs and the rollback guard.
- PowerSync 1.27.2 and temporary MongoDB used an isolated network. Two synthetic
  accounts received their own audio and written prayer/reflection metadata, not
  each other's records, private device audio or internal user IDs. A subsequent
  database update also reached only its owner.
- The temporary PowerSync, MongoDB and MySQL containers were stopped. Their
  rehearsal database storage was temporary; this is not a production backup.

## Additional rehearsal, 2026-11-04

- A fresh, restricted production snapshot restored into an isolated MySQL 8
  instance with all 67 base tables present. Its encrypted independent copy was
  decrypted and checksum-verified on the operator's computer. Neither copy is
  a final write-quiesced backup, and the restore did not compare every row.
- A separate MySQL database received only the production schema, followed by
  the candidate audio and owner migrations and synthetic accounts. The full
  candidate sync rules delivered complete, isolated prayer and reflection
  checkpoints to two accounts, and a later reflection reached only its owner.
  Invalid signatures and audiences were rejected. This did not exercise the
  production token controller, real devices, uploads, or public TLS.
- With binary logging enabled, a database-scoped migration account could not
  create triggers. The disposable rehearsal temporarily enabled
  `log_bin_trust_function_creators`, and disabled it again after migration.
  Production needs a reviewed migration privilege and durable trigger-definer
  plan; it must account for partially committed DDL on failure.

## Before any production cutover

1. Reconcile the application release with the deployed prayer-release branch;
   the older audio branch alone would omit production features and migrations.
2. Design and validate a production MySQL 8 deployment, capacity, backups,
   restore, monitoring, transport security and DNS. Configure GTID, binary
   logging, `ROW` format and `FULL` row images. Provision least-privileged
   database and trigger-definer accounts and a secured PowerSync service.
3. Rehearse a complete backup and restore, including routines and triggers,
   using those accounts. Confirm all table definitions, row counts and content
   against the source in a consistent time zone. Define and test rollback and
   recovery for failures after implicit MySQL DDL commits.
4. Quiesce **all** writers, including jobs and scheduled notifications; take and
   verify the final consistent backup; migrate and compare it. A live snapshot
   alone is insufficient because records can change while copying.
5. Apply the ordinary audio metadata migration on the target, then explicitly
   run `php artisan migrate --force --path=database/powersync` from `services/api`
   for the MySQL-only ownership projection. It is outside the ordinary migration
   directory so MariaDB upgrades do not run it. The owner migration deliberately
   refuses rollback once clients may depend on it.
   Confirm the exact deployed sync rules and the application's PowerSync URL,
   then verify isolation and subsequent changes with two staging accounts.
6. Release only after the combined candidate passes CI and physical Android
   recording, speaker/headphone handoff and background playback checks. iOS
   simulator CI does not replace a physical iPhone audio check.

The candidate rules are in `infra/powersync/self-hosted.sync-rules.yaml`. They
are not active production configuration. Audio files remain local to the device;
the rules synchronize metadata only.

The existing API token issuer uses HS256 and requires matching issuer, audience,
key ID and signing key in PowerSync's client authentication configuration. A
read-only check on 2026-11-04 found the production audience unset. Configure and
test the issuer and service together; do not print or commit signing keys. The
Play workflow requires the repository variable `SOULBUDDY_POWERSYNC_URL` to be
set to the verified HTTPS service endpoint and embeds it in the release bundle.
Endpoint syntax validation is not a service health or isolation check.
An endpoint with a path must end in `/`: the Flutter SDK resolves sync paths
relative to the endpoint URI, and a missing slash drops the last path segment.

## Unresolved release blocker

The Android speech-recognition handoff now waits for a native terminal callback.
That callback does not prove physical microphone hardware release: verify the
handoff on a device. A missing callback deliberately leaves capture locked.

Sacred Hour recorded playback uses the shared playback session and system media
controls. Its timer is held in the running app process and is not durable across
process death. Verify playback, capture handoff and notification actions on a
device.

The combined candidate has passed CI but has not been published. The production
PowerSync endpoint is not configured, and physical audio QA remains in progress.
