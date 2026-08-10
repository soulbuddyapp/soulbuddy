import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';

import '../domain/scripture_passage.dart';
import 'scripture_repository.dart';
import 'sqlite_scripture_repository.dart';

Future<ScripturePassage> loadBundledChapter({
  required String book,
  required int chapter,
}) async {
  try {
    final directory = await getApplicationSupportDirectory();
    final databaseFile = File(path_helper.join(directory.path, 'rsvce-v1.db'));
    if (!databaseFile.existsSync()) {
      final asset = await rootBundle.load('assets/scripture/rsvce.db');
      final bytes = Uint8List.sublistView(asset);
      await databaseFile.writeAsBytes(bytes, flush: true);
    }

    final repository = SqliteScriptureRepository.open(databaseFile.path);
    try {
      return await repository.chapter(book: book, chapter: chapter);
    } finally {
      repository.close();
    }
  } on ScriptureReferenceNotFound {
    rethrow;
  } on Object catch (error) {
    throw ScriptureSourceUnavailable(error);
  }
}
