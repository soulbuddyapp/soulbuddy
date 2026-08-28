import 'package:powersync/powersync.dart';

const goalTables = <Table>[
  Table(
    'goals',
    [
      Column.text('owner_id'),
      Column.text('starter_key'),
      Column.text('mode'),
      Column.text('status'),
      Column.text('current_revision_id'),
      Column.integer('position'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('archived_at'),
    ],
    indexes: [
      Index('goals_owner_status_position', [
        IndexedColumn('owner_id'),
        IndexedColumn('status'),
        IndexedColumn('position'),
      ]),
      Index('goals_owner_updated', [
        IndexedColumn('owner_id'),
        IndexedColumn('updated_at'),
      ]),
    ],
  ),
  Table(
    'goal_revisions',
    [
      Column.text('goal_id'),
      Column.text('owner_id'),
      Column.text('title'),
      Column.text('current_situation'),
      Column.text('why_it_matters'),
      Column.text('created_at'),
      Column.text('device_id'),
    ],
    indexes: [
      Index('goal_revisions_parent', [
        IndexedColumn('goal_id'),
        IndexedColumn('created_at'),
      ]),
    ],
  ),
  Table(
    'goal_links',
    [
      Column.text('goal_id'),
      Column.text('owner_id'),
      Column.text('link_type'),
      Column.text('personal_prayer_id'),
      Column.text('library_prayer_id'),
      Column.text('encounter_id'),
      Column.text('voice_tablet_id'),
      Column.text('circle_id'),
      Column.text('translation'),
      Column.text('book'),
      Column.integer('chapter'),
      Column.integer('first_verse'),
      Column.integer('last_verse'),
      Column.text('role'),
      Column.text('created_at'),
      Column.text('archived_at'),
    ],
    indexes: [
      Index('goal_links_parent', [
        IndexedColumn('goal_id'),
        IndexedColumn('archived_at'),
      ]),
      Index('goal_links_owner_type', [
        IndexedColumn('owner_id'),
        IndexedColumn('link_type'),
      ]),
    ],
  ),
  Table(
    'goal_actions',
    [
      Column.text('goal_id'),
      Column.text('owner_id'),
      Column.text('body'),
      Column.text('action_kind'),
      Column.text('schedule_type'),
      Column.text('local_time'),
      Column.text('timezone'),
      Column.text('once_at'),
      Column.integer('weekdays_mask'),
      Column.integer('enabled'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('archived_at'),
    ],
    indexes: [
      Index('goal_actions_owner_goal', [
        IndexedColumn('owner_id'),
        IndexedColumn('goal_id'),
        IndexedColumn('archived_at'),
      ]),
      Index('goal_actions_due', [
        IndexedColumn('owner_id'),
        IndexedColumn('enabled'),
        IndexedColumn('schedule_type'),
      ]),
    ],
  ),
  Table(
    'goal_action_events',
    [
      Column.text('goal_action_id'),
      Column.text('goal_id'),
      Column.text('owner_id'),
      Column.text('event_type'),
      Column.text('occurrence_key'),
      Column.text('occurred_at'),
      Column.text('local_date'),
      Column.text('device_id'),
    ],
    indexes: [
      Index('goal_action_events_occurrence', [
        IndexedColumn('owner_id'),
        IndexedColumn('goal_action_id'),
        IndexedColumn('occurrence_key'),
        IndexedColumn('occurred_at'),
      ]),
      Index('goal_action_events_goal_date', [
        IndexedColumn('owner_id'),
        IndexedColumn('goal_id'),
        IndexedColumn('local_date'),
      ]),
    ],
  ),
];
