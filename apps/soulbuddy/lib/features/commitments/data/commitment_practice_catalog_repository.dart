import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/commitment.dart';

class CommitmentPracticeSuggestion {
  const CommitmentPracticeSuggestion({
    required this.id,
    required this.category,
    required this.text,
  });
  final String id;
  final CommitmentPracticeCategory category;
  final String text;
}

class CommitmentPracticeCatalogRepository {
  const CommitmentPracticeCatalogRepository();
  Future<List<CommitmentPracticeSuggestion>> load({
    AssetBundle? bundle,
  }) async => parse(
    await (bundle ?? rootBundle).loadString(
      'assets/content/commitment_practices.json',
    ),
  );
  static List<CommitmentPracticeSuggestion> parse(String source) {
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      if (json['version'] != 1) throw const FormatException();
      final seen = <String>{};
      return List.unmodifiable(
        (json['practices'] as List).map((dynamic value) {
          final row = value as Map<String, dynamic>;
          final id = row['id'] as String;
          if (id.isEmpty || !seen.add(id) || row['reviewState'] != 'approved') {
            throw const FormatException();
          }
          return CommitmentPracticeSuggestion(
            id: id,
            category: CommitmentPracticeCategory.fromWire(
              row['category'] as String,
            ),
            text: validateCommitmentText('practice', row['text'] as String),
          );
        }),
      );
    } catch (_) {
      throw const FormatException('Invalid reviewed practice catalog');
    }
  }
}
