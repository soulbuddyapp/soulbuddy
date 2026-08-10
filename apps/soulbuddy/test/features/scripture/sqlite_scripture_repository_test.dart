import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:soulbuddy/features/scripture/data/scripture_repository.dart';
import 'package:soulbuddy/features/scripture/data/sqlite_scripture_repository.dart';

void main() {
  late Directory temporaryDirectory;
  late String databasePath;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-scripture-',
    );
    databasePath = '${temporaryDirectory.path}/scripture.db';
    final fixture = sqlite3.open(databasePath);
    fixture.execute('''
      CREATE TABLE books(
        _id INTEGER PRIMARY KEY,
        text TEXT,
        shortname TEXT
      );
      CREATE TABLE verses(
        _id INTEGER PRIMARY KEY,
        book_id INTEGER,
        chapter_id INTEGER,
        verse_id INTEGER,
        text TEXT
      );
      CREATE INDEX verses_lookup
      ON verses(book_id, chapter_id, verse_id);
    ''');
    fixture.execute(
      'INSERT INTO books(_id, text, shortname) VALUES (?, ?, ?)',
      [43, 'John', 'John'],
    );
    fixture.execute('INSERT INTO verses VALUES (?, ?, ?, ?, ?)', [
      2,
      43,
      3,
      2,
      'Second fixture verse.',
    ]);
    fixture.execute('INSERT INTO verses VALUES (?, ?, ?, ?, ?)', [
      1,
      43,
      3,
      1,
      'First fixture verse.',
    ]);
    fixture.dispose();
  });

  tearDown(() => temporaryDirectory.delete(recursive: true));

  test('loads a chapter in canonical verse order', () async {
    final repository = SqliteScriptureRepository.open(databasePath);
    addTearDown(repository.close);

    final passage = await repository.chapter(book: 'Jn', chapter: 3);

    expect(passage.reference, 'John 3');
    expect(passage.verses.map((verse) => verse.number), orderedEquals([1, 2]));
  });

  test('returns a typed not-found result for an unknown reference', () async {
    final repository = SqliteScriptureRepository.open(databasePath);
    addTearDown(repository.close);

    expect(
      () => repository.chapter(book: 'Unknown', chapter: 1),
      throwsA(isA<ScriptureReferenceNotFound>()),
    );
  });

  test('uses the composite verse lookup index', () {
    final database = sqlite3.open(databasePath, mode: OpenMode.readOnly);
    addTearDown(database.dispose);

    final plan = database.select(
      '''
      EXPLAIN QUERY PLAN
      SELECT v.verse_id, v.text
      FROM verses AS v
      WHERE v.book_id = ? AND v.chapter_id = ?
      ORDER BY v.verse_id
      ''',
      [43, 3],
    );
    final details = plan.map((row) => row['detail'] as String).join(' ');

    expect(details, contains('verses_lookup'));
    expect(details, isNot(contains('SCAN v')));
  });
}
