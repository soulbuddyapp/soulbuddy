import 'package:powersync/powersync.dart';

const appSchema = Schema([
  Table(
    'encounters',
    [
      Column.text('owner_id'),
      Column.text('title'),
      Column.text('body'),
      Column.text('occurred_on'),
      Column.integer('is_altar'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('archived_at'),
      Column.text('current_revision_id'),
    ],
    indexes: [
      Index('encounters_owner_date', [
        IndexedColumn('owner_id'),
        IndexedColumn('occurred_on'),
      ]),
    ],
  ),
  Table(
    'encounter_revisions',
    [
      Column.text('encounter_id'),
      Column.text('owner_id'),
      Column.text('title'),
      Column.text('body'),
      Column.text('created_at'),
      Column.text('device_id'),
    ],
    indexes: [
      Index('encounter_revisions_parent', [IndexedColumn('encounter_id')]),
    ],
  ),
  Table(
    'library_prayers',
    [
      Column.text('title'),
      Column.text('body'),
      Column.text('grounding'),
      Column.text('purpose'),
      Column.text('action'),
      Column.integer('helpful_count'),
      Column.text('published_at'),
      Column.text('archived_at'),
    ],
    indexes: [
      Index('library_prayers_order', [
        IndexedColumn('helpful_count'),
        IndexedColumn('title'),
      ]),
      Index('library_prayers_filter', [
        IndexedColumn('grounding'),
        IndexedColumn('purpose'),
      ]),
    ],
  ),
  Table.localOnly('bundled_prayers', [
    Column.text('title'),
    Column.text('body'),
    Column.text('grounding'),
    Column.text('purpose'),
    Column.text('action'),
    Column.integer('helpful_count'),
    Column.integer('content_version'),
    Column.text('archived_at'),
  ]),
  Table(
    'prayer_votes',
    [
      Column.text('owner_id'),
      Column.text('prayer_id'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('prayer_votes_owner_prayer', [
        IndexedColumn('owner_id'),
        IndexedColumn('prayer_id'),
      ]),
    ],
  ),
  Table(
    'today_prayers',
    [
      Column.text('owner_id'),
      Column.text('local_date'),
      Column.text('prayer_id'),
      Column.integer('include_action'),
      Column.integer('action_completed'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('today_prayers_owner_date', [
        IndexedColumn('owner_id'),
        IndexedColumn('local_date'),
      ]),
    ],
  ),
  Table.localOnly('sync_issues', [
    Column.text('record_type'),
    Column.text('record_id'),
    Column.text('code'),
    Column.text('message'),
    Column.text('created_at'),
    Column.text('resolved_at'),
  ]),
]);
