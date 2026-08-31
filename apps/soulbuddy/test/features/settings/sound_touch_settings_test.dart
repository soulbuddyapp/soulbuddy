import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/feedback/app_feedback.dart';
import 'package:soulbuddy/core/feedback/app_feedback_preferences.dart';
import 'package:soulbuddy/core/feedback/app_feedback_providers.dart';
import 'package:soulbuddy/core/feedback/app_feedback_service.dart';
import 'package:soulbuddy/core/feedback/platform_feedback_driver.dart';
import 'package:soulbuddy/core/feedback/completion_feedback.dart';
import 'package:soulbuddy/features/settings/presentation/settings_screen.dart';

void main() {
  testWidgets('changes sound, touch, and reduced motion immediately', (
    tester,
  ) async {
    final repository = _MemoryPreferencesRepository();
    final driver = _RecordingDriver();
    addTearDown(repository.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFeedbackPreferencesRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          appFeedbackPreferencesProvider.overrideWith(
            (ref) => repository.watch(),
          ),
          appFeedbackServiceProvider.overrideWithValue(
            AppFeedbackService(driver: driver),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sound & touch'), findsOneWidget);
    expect(_switch(tester, 'Haptics').value, isTrue);
    expect(_switch(tester, 'In-app sounds').value, isTrue);
    expect(_switch(tester, 'Reduce motion').value, isFalse);

    await tester.tap(find.text('Haptics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In-app sounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reduce motion'));
    await tester.pumpAndSettle();

    expect(repository.current.hapticsEnabled, isFalse);
    expect(repository.current.soundsEnabled, isFalse);
    expect(repository.current.reducedMotion, isTrue);
  });

  testWidgets('Test feedback uses current preferences', (tester) async {
    final repository = _MemoryPreferencesRepository();
    final driver = _RecordingDriver();
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFeedbackPreferencesRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          appFeedbackPreferencesProvider.overrideWith(
            (ref) => repository.watch(),
          ),
          appFeedbackServiceProvider.overrideWithValue(
            AppFeedbackService(driver: driver),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Test feedback'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test feedback'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CompletionFeedback));
    await tester.pumpAndSettle();

    expect(driver.haptics, [AppHaptic.medium]);
    expect(driver.sounds, [AppFeedbackSound.gentleCompletion]);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Feedback played' &&
            widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('remains usable at 200 percent text', (tester) async {
    final repository = _MemoryPreferencesRepository();
    addTearDown(repository.close);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFeedbackPreferencesRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          appFeedbackPreferencesProvider.overrideWith(
            (ref) => repository.watch(),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Test feedback'));
    await tester.pumpAndSettle();
    expect(find.text('Test feedback').hitTestable(), findsOneWidget);
  });
}

Switch _switch(WidgetTester tester, String title) {
  final tile = find.ancestor(
    of: find.text(title),
    matching: find.byType(SwitchListTile),
  );
  return tester.widget<Switch>(
    find.descendant(of: tile, matching: find.byType(Switch)),
  );
}

class _MemoryPreferencesRepository implements AppFeedbackPreferencesRepository {
  var current = AppFeedbackPreferences.defaults;
  final _changes = StreamController<AppFeedbackPreferences>.broadcast();

  @override
  Stream<AppFeedbackPreferences> watch() async* {
    yield current;
    yield* _changes.stream;
  }

  @override
  Future<void> save(AppFeedbackPreferences preferences) async {
    current = preferences;
    _changes.add(current);
  }

  @override
  Future<void> setHapticsEnabled(bool value) =>
      save(current.copyWith(hapticsEnabled: value));

  @override
  Future<void> setReducedMotion(bool value) =>
      save(current.copyWith(reducedMotion: value));

  @override
  Future<void> setSoundsEnabled(bool value) =>
      save(current.copyWith(soundsEnabled: value));

  Future<void> close() => _changes.close();
}

class _RecordingDriver implements PlatformFeedbackDriver {
  final haptics = <AppHaptic>[];
  final sounds = <AppFeedbackSound>[];

  @override
  Future<void> playHaptic(AppHaptic haptic) async => haptics.add(haptic);

  @override
  Future<void> playSound(AppFeedbackSound sound) async => sounds.add(sound);
}
