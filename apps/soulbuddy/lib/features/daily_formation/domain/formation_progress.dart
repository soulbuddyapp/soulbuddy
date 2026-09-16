class FormationProgress {
  const FormationProgress({
    required this.currentDay,
    required this.completions,
    this.selectedVideoId,
  });

  const FormationProgress.initial()
    : currentDay = 1,
      selectedVideoId = null,
      completions = const [];

  final int currentDay;
  final String? selectedVideoId;
  final List<FormationCompletion> completions;

  factory FormationProgress.fromJson(Map<dynamic, dynamic> json) {
    final completions = (json['completions'] as List? ?? const [])
        .whereType<Map>()
        .map(FormationCompletion.fromJson)
        .toList();
    final completedDays = completions.map((value) => value.day).toSet();
    final currentDay = (json['currentDay'] as num?)?.toInt() ?? 1;
    return FormationProgress(
      currentDay: currentDay.clamp(1, 71),
      selectedVideoId: json['selectedVideoId'] as String?,
      completions: completions.where((value) => value.day > 0).fold(
        <FormationCompletion>[],
        (items, value) {
          if (!items.any((item) => item.day == value.day)) items.add(value);
          return items;
        },
      ),
    )._withCurrentDayAtLeast(completedDays);
  }

  FormationProgress _withCurrentDayAtLeast(Set<int> completedDays) {
    var next = currentDay;
    while (completedDays.contains(next)) {
      next++;
    }
    return FormationProgress(
      currentDay: next.clamp(1, 71),
      selectedVideoId: selectedVideoId,
      completions: completions,
    );
  }

  Map<String, dynamic> toJson() => {
    'currentDay': currentDay,
    'selectedVideoId': selectedVideoId,
    'completions': completions.map((value) => value.toJson()).toList(),
  };

  FormationProgress select(String videoId) => FormationProgress(
    currentDay: currentDay,
    selectedVideoId: videoId,
    completions: completions,
  );

  FormationProgress addCompletion(FormationCompletion completion) {
    if (completions.any((item) => item.day == completion.day)) return this;
    final all = [...completions, completion];
    var next = currentDay;
    while (all.any((item) => item.day == next)) {
      next++;
    }
    return FormationProgress(currentDay: next.clamp(1, 71), completions: all);
  }
}

class FormationCompletion {
  const FormationCompletion({
    required this.day,
    required this.videoId,
    required this.completedAt,
    this.reflection,
    this.action,
  });

  final int day;
  final String videoId;
  final DateTime completedAt;
  final String? reflection;
  final String? action;

  factory FormationCompletion.fromJson(Map<dynamic, dynamic> json) =>
      FormationCompletion(
        day: (json['day'] as num).toInt(),
        videoId: json['videoId'] as String,
        completedAt: DateTime.parse(json['completedAt'] as String),
        reflection: json['reflection'] as String?,
        action: json['action'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'day': day,
    'videoId': videoId,
    'completedAt': completedAt.toUtc().toIso8601String(),
    if (reflection != null && reflection!.trim().isNotEmpty)
      'reflection': reflection!.trim(),
    if (action != null && action!.trim().isNotEmpty) 'action': action!.trim(),
  };
}
