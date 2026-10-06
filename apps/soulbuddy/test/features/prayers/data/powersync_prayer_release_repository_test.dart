import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/features/prayers/data/prayer_release_api_client.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_release_repository.dart';
import 'package:soulbuddy/features/prayers/data/powersync_prayer_repository.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_release.dart';

import '../../../helpers/powersync_test_database.dart';

const slug = 'renewed-mind-and-guarded-heart-v1';

const firstBody = '+\nJesus humbled himself unto death, even death on a Cross';
const repetitionBody =
    'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x50)\n'
    'In moments that distract me from your perfect will, let Satan be rebuked o Lord (x10)';

/// A JSON response. Bodies are UTF-8 encoded because the source wording
/// contains characters outside Latin-1.
http.Response jsonResponse(String body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, Object?> releasePayload({
  String libraryPrayerId = 'release-prayer-0',
  String id = 'release-item-0',
  int sortOrder = 0,
  String kind = 'prayer',
  bool hasAttentionPractice = false,
  String? addedAt,
}) {
  return {
    'id': 'release-1',
    'slug': slug,
    'title': 'Renewed mind & guarded heart',
    'discovery_label': 'This week’s prayer',
    'discovery_detail':
        'Prayer and meditation for purity, discipline, and a renewed mind.',
    'published_at': '2026-10-05T07:00:00+00:00',
    'added_at': addedAt,
    'items': [
      {
        'id': id,
        'sort_order': sortOrder,
        'kind': kind,
        'library_prayer_id': libraryPrayerId,
        'title': hasAttentionPractice
            ? 'New Adam repetitions'
            : 'Daily Prayer Against Temptations',
        'has_attention_practice': hasAttentionPractice,
        'narration_available': false,
      },
    ],
  };
}

/// The discovery response: metadata only, with the account's preference.
String discoveryBody({
  String libraryPrayerId = 'release-prayer-0',
  bool hasAttentionPractice = false,
  bool listed = true,
}) {
  return jsonEncode({
    'releases': listed
        ? [releasePayload(hasAttentionPractice: hasAttentionPractice)]
        : [],
    'preference': {
      'weekly_enabled': false,
      'notification_enabled': true,
      'time_zone': null,
    },
  });
}

String addedRow({
  bool hasPractice = false,
  String libraryPrayerId = 'release-prayer-0',
}) {
  final item = <String, Object?>{
    'id': 'release-item-0',
    'sort_order': 0,
    'kind': hasPractice ? 'meditation_prayer' : 'prayer',
    'library_prayer_id': libraryPrayerId,
    'title': hasPractice
        ? 'New Adam repetitions'
        : 'Daily Prayer Against Temptations',
    'body': hasPractice ? repetitionBody : firstBody,
    'grounding': 'general_christian',
    'language_style': 'christian',
    'purpose': hasPractice ? 'guidance' : 'daily',
    'action': null,
    'content_sha256': 'hash-0',
    'has_attention_practice': hasPractice,
    'narration_available': false,
    if (hasPractice)
      'practice': {
        'mode': 'affirmation_repetition',
        'steps': [
          {
            'phrase':
                'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus',
            'target_count': 50,
            'source_line':
                'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x50)',
          },
          {
            'phrase':
                'In moments that distract me from your perfect will, let Satan be rebuked o Lord',
            'target_count': 10,
            'source_line':
                'In moments that distract me from your perfect will, let Satan be rebuked o Lord (x10)',
          },
        ],
      },
  };

  return jsonEncode({
    ...releasePayload(
      libraryPrayerId: libraryPrayerId,
      kind: hasPractice ? 'meditation_prayer' : 'prayer',
      hasAttentionPractice: hasPractice,
      addedAt: '2026-10-06T09:00:00+00:00',
    ),
    'preference': {
      'weekly_enabled': false,
      'notification_enabled': true,
      'time_zone': null,
    },
    'preparation_text': 'Before you Pray',
    'items': [item],
  });
}

PowerSyncPrayerReleaseRepository buildRepository(
  dynamic database, {
  http.Client? httpClient,
  String ownerId = 'owner-1',
}) {
  return PowerSyncPrayerReleaseRepository(
    database: database,
    ownerId: ownerId,
    now: () => DateTime.utc(2026, 10, 6, 12),
    client: PrayerReleaseApiClient(
      apiBaseUri: Uri.parse('https://api.example.test'),
      accessToken: () async => 'session-token',
      httpClient:
          httpClient ??
          MockClient((request) async {
            return request.method == 'POST'
                ? jsonResponse(addedRow(), 201)
                : jsonResponse(discoveryBody(), 200);
          }),
    ),
  );
}

Future<void> seedReleasePrayer(
  dynamic database, {
  String id = 'release-prayer-0',
  String title = 'Daily Prayer Against Temptations',
}) async {
  await database.execute(
    '''
    INSERT INTO library_prayers(
      id, title, body, grounding, language_style, purpose, action,
      helpful_count, published_at, archived_at
    ) VALUES (?, ?, ?, 'general_christian', 'christian', 'daily', NULL, 3,
      '2026-10-05T07:00:00Z', NULL)
    ''',
    [id, title, firstBody],
  );
}

Future<void> seedOrdinaryPrayer(
  dynamic database, {
  String id = 'ordinary-prayer',
  String title = 'For this day',
}) async {
  await database.execute(
    '''
    INSERT INTO library_prayers(
      id, title, body, grounding, language_style, purpose, action,
      helpful_count, published_at, archived_at
    ) VALUES (?, ?, 'Ordinary prayer body.', 'general_christian', 'christian',
      'daily', NULL, 5, '2026-10-05T07:00:00Z', NULL)
    ''',
    [id, title],
  );
}

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'soulbuddy-prayer-releases-',
    );
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'keeps weekly release prayers out of the ordinary library before an add',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);
      await seedReleasePrayer(database.powersync);
      await seedOrdinaryPrayer(database.powersync);

      // Discovery has seen the release; the person has not added it.
      await buildRepository(database.powersync).refresh();

      final repository = PowerSyncPrayerRepository(
        database: database.powersync,
        ownerId: 'owner-1',
      );

      final titles = (await repository.watchLibrary().first)
          .map((prayer) => prayer.title)
          .toList();

      expect(titles, contains('For this day'));
      expect(titles, isNot(contains('Daily Prayer Against Temptations')));
    },
  );

  test('shows the exact release prayers in the library after an add', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);
    await seedReleasePrayer(database.powersync);
    await seedOrdinaryPrayer(database.powersync);

    final releases = buildRepository(database.powersync);
    await releases.refresh();
    await releases.addRelease(slug);

    final library = PowerSyncPrayerRepository(
      database: database.powersync,
      ownerId: 'owner-1',
    );
    final prayers = await library.watchLibrary().first;

    expect(
      prayers.map((prayer) => prayer.title),
      containsAll(['For this day', 'Daily Prayer Against Temptations']),
    );
    expect(
      prayers
          .firstWhere(
            (prayer) => prayer.title == 'Daily Prayer Against Temptations',
          )
          .body,
      firstBody,
    );
  });

  test(
    'does not leak one account download into another account library',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);
      await seedReleasePrayer(database.powersync);

      await buildRepository(
        database.powersync,
        ownerId: 'owner-1',
      ).addRelease(slug);

      final otherAccount = PowerSyncPrayerRepository(
        database: database.powersync,
        ownerId: 'owner-2',
      );
      final titles = (await otherAccount.watchLibrary().first)
          .map((prayer) => prayer.title)
          .toList();

      expect(titles, isNot(contains('Daily Prayer Against Temptations')));
    },
  );

  test(
    'caches the exact content offline so a reopened app still has it',
    () async {
      final path = '${temporaryDirectory.path}/soulbuddy.db';
      var online = true;
      late http.Client client;
      client = MockClient((request) async {
        if (!online) {
          throw http.ClientException('offline', request.url);
        }

        return request.method == 'POST'
            ? jsonResponse(addedRow(hasPractice: true), 201)
            : jsonResponse(discoveryBody(hasAttentionPractice: true), 200);
      });

      final first = await openTestDatabase(path);
      await buildRepository(
        first.powersync,
        httpClient: client,
      ).addRelease(slug);
      await first.close();

      // The network is gone and the app is reopened.
      online = false;
      final second = await openTestDatabase(path);
      addTearDown(second.close);

      final content = await buildRepository(
        second.powersync,
        httpClient: client,
      ).watchReleaseContent(slug).first;

      expect(content, hasLength(1));
      expect(content.single.body, repetitionBody);
      expect(content.single.title, 'New Adam repetitions');
      expect(content.single.action, isNull);
      expect(content.single.practice?.steps, hasLength(2));
      expect(content.single.practice?.mode, 'affirmation_repetition');
      expect(
        content.single.practice!.steps.first.sourceLine,
        'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x50)',
      );
      expect(
        content.single.practice!.steps.map((step) => step.rebuildsSourceLine()),
        everyElement(isTrue),
      );
    },
  );

  test(
    'keeps discovery metadata out of the content cache before an add',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);

      final repository = buildRepository(database.powersync);
      await repository.refresh();

      final content = await repository.watchReleaseContent(slug).first;
      expect(content, isEmpty);

      final rows = await database.powersync.getAll(
        'SELECT * FROM prayer_release_cache',
      );
      expect(rows, hasLength(1));
      expect(rows.single['added_at'], isNull);

      final body = await database.powersync.getOptional(
        "SELECT body FROM prayer_release_item_content LIMIT 1",
      );
      expect(body, isNull);
    },
  );

  test('makes a repeated add idempotent', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);

    final repository = buildRepository(database.powersync);
    final first = await repository.addRelease(slug);
    final second = await repository.addRelease(slug);

    expect(second.libraryPrayerId, first.libraryPrayerId);
    expect(await repository.hasLocalDownload(slug), isTrue);

    final downloads = await database.powersync.getAll(
      'SELECT * FROM prayer_release_downloads',
    );
    expect(downloads, hasLength(1));

    final content = await repository.watchReleaseContent(slug).first;
    expect(content, hasLength(1));
  });

  test('leaves no partial download when the add request fails', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);

    final repository = buildRepository(
      database.powersync,
      httpClient: MockClient(
        (_) async => throw http.ClientException('offline'),
      ),
    );

    await expectLater(repository.addRelease(slug), throwsA(anything));

    final downloads = await database.powersync.getAll(
      'SELECT * FROM prayer_release_downloads',
    );
    final content = await database.powersync.getAll(
      'SELECT * FROM prayer_release_item_content',
    );
    expect(downloads, isEmpty);
    expect(content, isEmpty);
    expect(await repository.hasLocalDownload(slug), isFalse);
  });

  test('lists only releases this account has added', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);

    final repository = buildRepository(database.powersync);
    await repository.refresh();
    expect(await repository.watchAddedReleases().first, isEmpty);

    await repository.addRelease(slug);
    final added = await repository.watchAddedReleases().first;

    expect(added, hasLength(1));
    expect(added.single.slug, slug);
    expect(added.single.added, isTrue);
    expect(added.single.addedAt, DateTime.utc(2026, 10, 6, 9));
  });

  test(
    'caches the weekly preference and keeps opt-in off by default',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);

      final repository = buildRepository(
        database.powersync,
        httpClient: MockClient((request) async {
          if (request.method == 'PUT') {
            final sent = jsonDecode(request.body) as Map<String, dynamic>;

            return jsonResponse(
              jsonEncode({
                'preference': {
                  'weekly_enabled': sent['weekly_enabled'],
                  'notification_enabled': sent['weekly_enabled'] == true
                      ? sent['notification_enabled']
                      : false,
                  'time_zone': sent['time_zone'],
                },
              }),
              200,
            );
          }

          return jsonResponse(discoveryBody(), 200);
        }),
      );
      await repository.refresh();

      final cached = await repository.watchPreference().first;
      expect(cached.weeklyEnabled, isFalse);
      expect(cached.notificationEnabled, isTrue);
      expect(cached.receivesDelivery, isFalse);

      await repository.savePreference(
        const PrayerReleasePreference(
          weeklyEnabled: true,
          notificationEnabled: true,
          timeZone: 'Africa/Lagos',
        ),
      );

      final saved = await repository.watchPreference().first;
      expect(saved.weeklyEnabled, isTrue);
      expect(saved.notificationEnabled, isTrue);
      expect(saved.timeZone, 'Africa/Lagos');
      expect(saved.receivesDelivery, isTrue);
    },
  );

  test('stops future delivery when weekly opt-in is turned off', () async {
    final database = await openTestDatabase(
      '${temporaryDirectory.path}/soulbuddy.db',
    );
    addTearDown(database.close);

    var weekly = false;
    final repository = buildRepository(
      database.powersync,
      httpClient: MockClient((request) async {
        if (request.method == 'PUT') {
          final sent = jsonDecode(request.body) as Map<String, dynamic>;
          weekly = sent['weekly_enabled'] == true;

          return jsonResponse(
            jsonEncode({
              'preference': {
                'weekly_enabled': weekly,
                'notification_enabled': weekly,
                'time_zone': sent['time_zone'],
              },
            }),
            200,
          );
        }

        if (request.method == 'POST') {
          return jsonResponse(addedRow(), 201);
        }

        return jsonResponse(
          jsonEncode({
            'releases': [],
            'preference': {
              'weekly_enabled': weekly,
              'notification_enabled': weekly,
              'time_zone': null,
            },
          }),
          200,
        );
      }),
    );

    await repository.addRelease(slug);
    await repository.savePreference(
      const PrayerReleasePreference(weeklyEnabled: true, timeZone: 'UTC'),
    );
    await repository.savePreference(const PrayerReleasePreference());

    final saved = await repository.watchPreference().first;
    expect(saved.weeklyEnabled, isFalse);
    expect(saved.receivesDelivery, isFalse);
    // Content that was already added is untouched.
    expect(await repository.watchReleaseContent(slug).first, hasLength(1));
  });

  test(
    'keeps an added release readable after the server stops listing it',
    () async {
      final database = await openTestDatabase(
        '${temporaryDirectory.path}/soulbuddy.db',
      );
      addTearDown(database.close);

      var listed = true;
      final repository = buildRepository(
        database.powersync,
        httpClient: MockClient((request) async {
          if (request.method == 'POST') {
            return jsonResponse(addedRow(), 201);
          }

          return jsonResponse(
            listed ? discoveryBody() : discoveryBody(listed: false),
            200,
          );
        }),
      );

      await repository.addRelease(slug);
      listed = false;
      await repository.refresh();

      final content = await repository.watchReleaseContent(slug).first;
      final added = await repository.watchAddedReleases().first;

      expect(content, hasLength(1));
      expect(added, hasLength(1));
      expect(content.single.body, firstBody);
    },
  );
}
