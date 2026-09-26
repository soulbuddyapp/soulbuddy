import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/presentation/commitment_personal_prayer_picker.dart';
import 'package:soulbuddy/features/commitments/providers/commitment_prayer_narration_providers.dart';
import 'package:soulbuddy/features/prayers/providers/personal_prayer_providers.dart';
import 'package:soulbuddy/features/prayers/domain/personal_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/library_prayer.dart';

void main() {
  testWidgets(
    'saved prayer selection stays usable when narration consent is cancelled',
    (tester) async {
      final calls = <String>[];
      final prayer = PersonalPrayer(
        id: 'p',
        ownerId: 'owner',
        title: 'Evening prayer',
        style: 'situational',
        reach: 'personal',
        grounding: PrayerGrounding.generalChristian,
        purpose: PrayerPurpose.daily,
        currentRevisionId: 'revision',
        body: 'Lord give me peace.',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            personalPrayersProvider.overrideWith(
              (ref) => Stream.value([prayer]),
            ),
            commitmentPreparePrayerProvider.overrideWithValue(({
              required personalPrayerId,
              required revisionId,
              required consent,
            }) async {
              calls.add('$personalPrayerId:$revisionId:$consent');
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CommitmentPersonalPrayerPicker(
                selectedPrayerId: 'p',
                selectedRevisionId: 'revision',
                onChanged: (p, r) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.text('Prepare narration'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Deepgram'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.text('Prepare narration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept and prepare'));
      await tester.pumpAndSettle();
      expect(calls, ['p:revision:true']);
    },
  );
}
