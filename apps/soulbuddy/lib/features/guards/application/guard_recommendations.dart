import '../domain/guard_definition.dart';

List<GuardDefinition> recommendedGuardDefinitions({
  required Iterable<GuardDefinition> definitions,
  required String? contextTag,
  int maximum = 4,
}) {
  if (maximum <= 0 || contextTag == null || contextTag.trim().isEmpty) {
    return const [];
  }
  final result = <GuardDefinition>[];
  for (final definition in definitions) {
    if (definition.archived ||
        !definition.goalContextTags.contains(contextTag)) {
      continue;
    }
    result.add(definition);
    if (result.length == maximum) break;
  }
  return List.unmodifiable(result);
}
