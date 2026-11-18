import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/persons/data/person_prayer_audio_repository.dart';
import 'package:soulbuddy/features/persons/presentation/person_prayer_audio_section.dart';
import 'package:soulbuddy/features/persons/providers/person_prayer_audio_providers.dart';
import 'package:soulbuddy/features/prayers/application/prayer_audio_environment.dart';
import 'package:soulbuddy/features/prayers/application/prayer_narration_playback_policy.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_player.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';

class Environment implements PrayerAudioEnvironment {
  Environment({this.allowed = true});
  final bool allowed;
  @override
  Future<PrayerAudioRoute> currentRoute() async => PrayerAudioRoute.speaker;
  @override
  Future<bool> interruptionsAllowed() async => allowed;
}

class Store implements AudioAssetStore {
  @override
  Future<AudioPlaybackSource?> open(String key) async =>
      BytesAudioPlaybackSource(Uint8List.fromList([1]), mimeType: 'audio/mp4');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Driver implements MemoryAudioPlayerDriver {
  var played = 0;
  @override
  Stream<Duration> get positionChanges => const Stream.empty();
  @override
  Stream<Duration> get durationChanges => const Stream.empty();
  @override
  Stream<MemoryAudioDriverStatus> get statusChanges => const Stream.empty();
  @override
  Future<void> prepare(String id, AudioPlaybackSource source) async {}
  @override
  Future<void> play(String id, AudioPlaybackSource source) async {
    played++;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> release(String id) async {}
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('opens a recorded person prayer after its reminder', (
    tester,
  ) async {
    final driver = Driver();
    final player = MemoryAudioPlaybackCoordinator(
      assetStore: Store(),
      driver: driver,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personPrayerAudioProvider.overrideWith(
            (ref, id) async => const PersonPrayerAudio(
              storageKey: 'audio/a.m4a',
              duration: Duration(seconds: 2),
            ),
          ),
          personPrayerAudioPlaybackProvider.overrideWith((ref) async => player),
          prayerAudioEnvironmentProvider.overrideWithValue(Environment()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PersonPrayerAudioSection(personId: 'p1', autoplay: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(driver.played, 1);
  });
  testWidgets(
    'does not autoplay a private recording when interruptions are blocked',
    (tester) async {
      final driver = Driver();
      final player = MemoryAudioPlaybackCoordinator(
        assetStore: Store(),
        driver: driver,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            personPrayerAudioProvider.overrideWith(
              (ref, id) async => const PersonPrayerAudio(
                storageKey: 'audio/a.m4a',
                duration: Duration(seconds: 2),
              ),
            ),
            personPrayerAudioPlaybackProvider.overrideWith(
              (ref) async => player,
            ),
            prayerAudioEnvironmentProvider.overrideWithValue(
              Environment(allowed: false),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PersonPrayerAudioSection(personId: 'p1', autoplay: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(driver.played, 0);
      expect(find.text('Play prayer'), findsOneWidget);
    },
  );
}
