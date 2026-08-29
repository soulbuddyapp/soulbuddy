import 'package:powersync/powersync.dart';

const editorialTables = [
  Table.localOnly(
    'editorial_items',
    [
      Column.text('content_kind'),
      Column.integer('content_version'),
      Column.text('provenance'),
      Column.text('source_ref'),
      Column.text('review_state'),
      Column.text('reviewed_on'),
      Column.text('published_at'),
      Column.text('archived_at'),
      Column.text('tags_json'),
    ],
    indexes: [
      Index('editorial_items_selection', [
        IndexedColumn('content_kind'),
        IndexedColumn('review_state'),
        IndexedColumn('archived_at'),
      ]),
    ],
  ),
];
