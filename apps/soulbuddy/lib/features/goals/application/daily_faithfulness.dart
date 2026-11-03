import '../data/goal_repository.dart';
import '../domain/goal.dart';
import '../domain/goal_action.dart';

enum SpiritualPrecept {
  guardTheGate,
  strengthForToday;

  String get title =>
      this == guardTheGate ? 'Guard the gate' : 'Strength for today';
  String get teaching => this == guardTheGate
      ? 'Just because you have a key to the forbidden fruit\ndoes not mean you should open the gate.\nLock the gate,\nand throw away the key.\nAmen.'
      : 'Grace is a gift, and we grow by cooperating with it. '
            'Like a spiritual gym, daily prayer and steady practice strengthen the inner life. '
            'Ask God for a task you can carry today, and give it your best.';
  String get prayer => this == guardTheGate
      ? 'Lord, help me close the gate to temptation and plant something good today. Amen.'
      : 'Lord, give me a task I can carry today, and the grace to give it my best. Amen.';
  String get reflection => this == guardTheGate
      ? 'Which gate needs closing? What good action will take its place?'
      : 'What did I carry with love today? Where do I need grace and a smaller next step?';
  List<String> get suggestions => this == guardTheGate
      ? const [
          'Remove one easy path to temptation',
          'Silence a distraction during prayer',
          'Ask someone trustworthy for accountability',
        ]
      : const [
          'Give five undistracted minutes to prayer',
          'Finish one manageable act of care or duty',
          'Help someone without seeking recognition',
        ];
}

class DailyFaithfulness {
  DailyFaithfulness(this.goals);
  final GoalRepository goals;
  Future<void> _pending = Future.value();

  Future<GoalAction> save({
    required SpiritualPrecept precept,
    required String body,
    required DateTime localDate,
    String? goalId,
    bool repeatDaily = false,
  }) {
    final saving = _pending.then((_) async {
      final trimmed = body.trim();
      if (trimmed.isEmpty ||
          trimmed.runes.length > 120 ||
          trimmed.contains('\n')) {
        throw ArgumentError(
          'A single action label of 1–120 characters is required.',
        );
      }
      final active = await goals.watchActive().first;
      Goal? goal;
      if (goalId != null) {
        goal = active.where((value) => value.id == goalId).firstOrNull;
        if (goal == null) throw StateError('This goal is no longer active.');
      } else {
        goal = active
            .where((value) => value.title == precept.title)
            .firstOrNull;
      }
      goal ??= await goals.create(
        title: precept.title,
        mode: GoalMode.actionable,
        starterKey: precept == SpiritualPrecept.guardTheGate
            ? GoalStarterKey.stopControl
            : GoalStarterKey.other,
        whyItMatters: 'Grow in faithfulness through prayer and daily action.',
      );
      final schedule = repeatDaily
          ? GoalScheduleType.daily
          : GoalScheduleType.today;
      final reader = goals;
      final due =
          await (reader is GoalDailyActionReader
                  ? (reader as GoalDailyActionReader).watchScheduledActions(
                      localDate,
                    )
                  : reader.watchDueActions(localDate))
              .first;
      final existing = due
          .where(
            (item) =>
                item.action.goalId == goal!.id &&
                item.action.body == trimmed &&
                item.action.scheduleType == schedule,
          )
          .firstOrNull;
      if (existing != null) return existing.action;
      return goals.addAction(
        goal.id,
        GoalActionDraft(
          body: trimmed,
          kind: precept == SpiritualPrecept.guardTheGate
              ? GoalActionKind.guard
              : GoalActionKind.nextStep,
          scheduleType: schedule,
          onceAt: repeatDaily ? null : localDate,
        ),
      );
    });
    _pending = saving.then<void>((_) {}, onError: (Object _) {});
    return saving;
  }
}
