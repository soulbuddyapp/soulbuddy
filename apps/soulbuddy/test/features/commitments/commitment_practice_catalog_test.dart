import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/data/commitment_practice_catalog_repository.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';

void main() {
  final source = File(
    'assets/content/commitment_practices.json',
  ).readAsStringSync();
  test(
    'catalog contains six approved choices per category with unique IDs',
    () {
      final entries = CommitmentPracticeCatalogRepository.parse(source);
      expect(entries, hasLength(18));
      expect(entries.map((e) => e.id).toSet(), hasLength(18));
      for (final category in CommitmentPracticeCategory.values) {
        expect(entries.where((e) => e.category == category), hasLength(6));
      }
    },
  );
  for (final mutation in ['duplicate', 'unknown', 'unapproved', 'empty']) {
    test('catalog rejects $mutation without exposing source content', () {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final rows = json['practices'] as List<dynamic>;
      if (mutation == 'duplicate') rows.add(rows.first);
      if (mutation == 'unknown') {
        rows.first['category'] = 'private unknown category';
      }
      if (mutation == 'unapproved') rows.first['reviewState'] = 'draft';
      if (mutation == 'empty') rows.first['text'] = '';
      expect(
        () => CommitmentPracticeCatalogRepository.parse(jsonEncode(json)),
        throwsFormatException,
      );
    });
  }
}
