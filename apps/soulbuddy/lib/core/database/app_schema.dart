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
  Table.localOnly('sync_issues', [
    Column.text('record_type'),
    Column.text('record_id'),
    Column.text('code'),
    Column.text('message'),
    Column.text('created_at'),
    Column.text('resolved_at'),
  ]),
]);
