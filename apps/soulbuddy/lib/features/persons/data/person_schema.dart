import 'package:powersync/powersync.dart';

const personTables = <Table>[
  Table(
    'prayer_people',
    [
      Column.text('owner_id'),
      Column.text('name'),
      Column.text('relationship'),
      Column.text('cadence'),
      Column.text('local_time'),
      Column.text('timezone'),
      Column.integer('weekdays_mask'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('archived_at'),
    ],
    indexes: [
      Index('prayer_people_owner_name', [
        IndexedColumn('owner_id'),
        IndexedColumn('name'),
      ]),
    ],
  ),
  Table(
    'person_prayer_occurrences',
    [
      Column.text('person_id'),
      Column.text('owner_id'),
      Column.text('local_date'),
      Column.text('occurrence_key'),
      Column.text('prayed_at'),
      Column.text('device_id'),
    ],
    indexes: [
      Index('person_prayer_occurrence_key', [
        IndexedColumn('owner_id'),
        IndexedColumn('occurrence_key'),
      ]),
    ],
  ),
  Table(
    'encounter_person_links',
    [
      Column.text('encounter_id'),
      Column.text('person_id'),
      Column.text('owner_id'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('encounter_person_link_person', [
        IndexedColumn('owner_id'),
        IndexedColumn('person_id'),
      ]),
    ],
  ),
];
