import 'dart:convert';

import 'package:powersync/powersync.dart';
import 'package:powersync/sqlite_async.dart';
import 'package:uuid/uuid.dart';

import '../domain/affirmation_prayer.dart';
import '../domain/prayer_release.dart';
import 'prayer_release_api_client.dart';
import 'prayer_release_repository.dart';

/// Local release storage over PowerSync.
///
/// Discovery metadata and the preference are mirrored from the authenticated
/// API. The exact wording is only written after a deliberate add, and the write
/// is transactional: a network failure leaves no partial local download.
class PowerSyncPrayerReleaseRepository implements PrayerReleaseRepository {
  PowerSyncPrayerReleaseRepository({
    required this.database,
    required this.ownerId,
    required this.client,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final PowerSyncDatabase database;
  final String ownerId;
  final PrayerReleaseApiClient client;
  final DateTime Function() _now;
  final Uuid _uuid;

  @override
  Stream<List<PrayerRelease>> watchReleases() {
    return database.watch('''
      SELECT cached.*, added.downloaded_at AS local_added_at
      FROM prayer_release_cache AS cached
      LEFT JOIN prayer_release_downloads AS added
        ON added.release_id = cached.id
       AND added.owner_id = ?
       AND added.release_slug = cached.slug
      ORDER BY COALESCE(added.downloaded_at, cached.published_at) DESC,
               cached.slug ASC
      ''', parameters: [ownerId]).asyncMap((rows) async {
        final items = await _itemsFor(
          rows.map((row) => row['slug'] as String).toList(growable: false),
        );

        return List.unmodifiable([
          for (final row in rows)
            _releaseFromRow(row, items: items[row['slug'] as String] ?? const []),
        ]);
      });
  }

  @override
  Stream<List<PrayerRelease>> watchAddedReleases() {
    return database.watch('''
      SELECT cached.*, added.downloaded_at AS local_added_at
      FROM prayer_release_cache AS cached
      JOIN prayer_release_downloads AS added
        ON added.release_id = cached.id
       AND added.owner_id = ?
       AND added.release_slug = cached.slug
      WHERE cached.added_at IS NOT NULL
      ORDER BY added.downloaded_at DESC
      ''', parameters: [ownerId]).asyncMap((rows) async {
        final items = await _itemsFor(
          rows.map((row) => row['slug'] as String).toList(growable: false),
        );

        return List.unmodifiable([
          for (final row in rows)
            _releaseFromRow(
              row,
              items: items[row['slug'] as String] ?? const [],
            ),
        ]);
      });
  }

  @override
  Stream<PrayerRelease?> watchRelease(String slug) {
    return database.watch('''
      SELECT cached.*, added.downloaded_at AS local_added_at
      FROM prayer_release_cache AS cached
      LEFT JOIN prayer_release_downloads AS added
        ON added.release_id = cached.id
       AND added.owner_id = ?
       AND added.release_slug = cached.slug
      WHERE cached.slug = ?
      LIMIT 1
      ''', parameters: [ownerId, slug]).asyncMap((rows) async {
        if (rows.isEmpty) return null;
        final items = await _itemsFor([slug]);

        return _releaseFromRow(
          rows.single,
          items: items[slug] ?? const [],
        );
      });
  }

  @override
  Stream<List<PrayerReleaseItemContent>> watchReleaseContent(String slug) {
    return database.watch('''
      SELECT * FROM prayer_release_item_content
      WHERE owner_id = ? AND release_slug = ?
      ORDER BY sort_order ASC
      ''', parameters: [ownerId, slug]).map((rows) {
        return List.unmodifiable(
          rows.map(PrayerReleaseItemContent.fromRow),
        );
      });
  }

  @override
  Stream<PrayerReleaseItemContent?> watchContentForPrayer(
    String libraryPrayerId,
  ) {
    return database.watch('''
      SELECT * FROM prayer_release_item_content
      WHERE owner_id = ? AND library_prayer_id = ?
      ORDER BY release_slug ASC, sort_order ASC
      LIMIT 1
      ''', parameters: [ownerId, libraryPrayerId]).map((rows) {
        return rows.isEmpty ? null : PrayerReleaseItemContent.fromRow(rows.single);
      });
  }

  @override
  Stream<PrayerReleasePreference> watchPreference() {
    return database.watch(
      'SELECT * FROM prayer_release_preference_cache LIMIT 1',
    ).map((rows) {
      return rows.isEmpty
          ? const PrayerReleasePreference()
          : PrayerReleasePreference.fromRow(rows.single);
    });
  }

  @override
  Future<void> refresh() async {
    final snapshot = await client.fetch();

    await database.writeTransaction((transaction) async {
      await _replaceDiscovery(transaction, snapshot.releases);
      await _savePreferenceRow(transaction, snapshot.preference);
    });
  }

  @override
  Future<void> retry() => refresh();

  @override
  Future<PrayerReleaseItemContent> addRelease(String slug) async {
    // The server owns the add, so a network failure throws before any local
    // write happens and nothing partial is left behind.
    final added = await client.add(slug);
    final addedAt = added.release.addedAt ?? _now();

    await database.writeTransaction((transaction) async {
      await _replaceDiscovery(transaction, [added.release]);
      await _savePreferenceRow(transaction, added.preference);

      // Adding is idempotent, so the stored download date never moves.
      final downloadId = _uuid.v5(
        Namespace.url.value,
        'prayer-release-download:$ownerId:${added.release.slug}',
      );
      final existing = await transaction.getOptional(
        'SELECT id FROM prayer_release_downloads WHERE id = ?',
        [downloadId],
      );
      if (existing == null) {
        await transaction.execute(
          '''
          INSERT INTO prayer_release_downloads(
            id, owner_id, release_id, release_slug, downloaded_at, synced_at
          ) VALUES (?, ?, ?, ?, ?, NULL)
          ''',
          [
            downloadId,
            ownerId,
            added.release.id,
            added.release.slug,
            addedAt.toUtc().toIso8601String(),
          ],
        );
      }

      for (final item in added.items) {
        await _cacheItemContent(transaction, added.release.slug, item);
      }
    });

    return added.items.first;
  }

  @override
  Future<void> savePreference(PrayerReleasePreference preference) async {
    final saved = await client.savePreference(preference);

    await database.writeTransaction(
      (transaction) => _savePreferenceRow(transaction, saved),
    );
  }

  @override
  Future<void> saveAffirmationSession(
    AffirmationPrayerSession session,
  ) async {
    AffirmationPrayerSession.validate(
      outcome: session.outcome,
      stepOneCount: session.stepOneCount,
      stepTwoCount: session.stepTwoCount,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
    );

    // A terminal record is written once; a retry of the same session id keeps
    // the stored counts.
    final existing = await database.getOptional(
      'SELECT id FROM affirmation_prayer_sessions WHERE id = ?',
      [session.id],
    );
    if (existing != null) return;

    final now = _now().toUtc().toIso8601String();
    await database.execute('''
      INSERT INTO affirmation_prayer_sessions(
        id, owner_id, release_item_id, local_date, started_at, ended_at,
        outcome, step_one_count, step_two_count, sound_key, narration_speed,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
      session.id,
      ownerId,
      session.releaseItemId,
      session.localDate,
      session.startedAt.toUtc().toIso8601String(),
      session.endedAt.toUtc().toIso8601String(),
      session.outcome.wireValue,
      session.stepOneCount,
      session.stepTwoCount,
      session.soundKey,
      session.narrationSpeed?.toString(),
      now,
      now,
    ]);
  }

  /// Whether this account has a local download for the release.
  Future<bool> hasLocalDownload(String slug) async {
    final row = await database.getOptional('''
      SELECT id FROM prayer_release_downloads
      WHERE owner_id = ? AND release_slug = ?
      LIMIT 1
      ''', [ownerId, slug]);

    return row != null;
  }

  Future<void> _replaceDiscovery(
    SqliteWriteContext transaction,
    List<PrayerRelease> releases,
  ) async {
    final now = _now().toUtc().toIso8601String();

    for (final release in releases) {
      final values = [
        release.id,
        release.slug,
        release.title,
        release.discoveryLabel,
        release.discoveryDetail,
        release.publishedAt?.toUtc().toIso8601String(),
        release.addedAt?.toUtc().toIso8601String(),
        now,
      ];
      final existing = await transaction.getOptional(
        'SELECT id FROM prayer_release_cache WHERE id = ?',
        [release.id],
      );
      if (existing == null) {
        await transaction.execute('''
          INSERT INTO prayer_release_cache(
            id, slug, title, discovery_label, discovery_detail,
            published_at, added_at, refreshed_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''', values);
      } else {
        await transaction.execute('''
          UPDATE prayer_release_cache
          SET slug = ?, title = ?, discovery_label = ?, discovery_detail = ?,
              published_at = ?, added_at = ?, refreshed_at = ?
          WHERE id = ?
          ''', [
          ...values.skip(1),
          release.id,
        ]);
      }

      // Discovery metadata only; no wording is stored here.
      for (final item in release.items) {
        final cacheId = _uuid.v5(
          Namespace.url.value,
          'prayer-release-item-cache:${release.slug}:${item.sortOrder}',
        );
        final itemValues = [
          cacheId,
          release.id,
          release.slug,
          item.sortOrder,
          item.id,
          item.kind.wireValue,
          item.libraryPrayerId,
          item.title,
          item.hasAttentionPractice ? 1 : 0,
          item.narrationAvailable ? 1 : 0,
        ];
        final cached = await transaction.getOptional(
          'SELECT id FROM prayer_release_item_cache WHERE id = ?',
          [cacheId],
        );
        if (cached == null) {
          await transaction.execute('''
            INSERT INTO prayer_release_item_cache(
              id, release_id, release_slug, sort_order, item_id, kind,
              library_prayer_id, title, has_attention_practice,
              narration_available
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', itemValues);
        } else {
          await transaction.execute('''
            UPDATE prayer_release_item_cache
            SET sort_order = ?, item_id = ?, kind = ?, library_prayer_id = ?,
                title = ?, has_attention_practice = ?, narration_available = ?
            WHERE id = ?
            ''', [...itemValues.sublist(3), cacheId]);
        }
      }
    }
  }

  Future<void> _cacheItemContent(
    SqliteWriteContext transaction,
    String slug,
    PrayerReleaseItemContent item,
  ) async {
    final cacheId = _uuid.v5(
      Namespace.url.value,
      'prayer-release-content:$ownerId:$slug:${item.sortOrder}',
    );
    final steps = item.practice == null
        ? null
        : jsonEncode([
            for (final step in item.practice!.steps)
              {
                'phrase': step.phrase,
                'target_count': step.targetCount,
                'source_line': step.sourceLine,
              },
          ]);
    final cachedAt = _now().toUtc().toIso8601String();

    final existing = await transaction.getOptional(
      'SELECT id FROM prayer_release_item_content WHERE id = ?',
      [cacheId],
    );
    if (existing == null) {
      await transaction.execute('''
        INSERT INTO prayer_release_item_content(
          id, owner_id, release_id, release_slug, item_id, sort_order, kind,
          library_prayer_id, title, body, grounding, language_style, purpose,
          action, content_sha256, practice_mode, practice_steps_json, cached_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
        cacheId,
        ownerId,
        item.releaseId,
        slug,
        _uuid.v5(
          Namespace.url.value,
          'prayer-release-content-item:$slug:${item.sortOrder}',
        ),
        item.sortOrder,
        item.kind.wireValue,
        item.libraryPrayerId,
        item.title,
        item.body,
        item.grounding,
        item.languageStyle,
        item.purpose,
        item.action,
        item.contentSha256,
        item.practice?.mode,
        steps,
        cachedAt,
      ]);

      return;
    }

    await transaction.execute('''
      UPDATE prayer_release_item_content
      SET title = ?, body = ?, content_sha256 = ?, practice_mode = ?,
          practice_steps_json = ?, cached_at = ?
      WHERE id = ?
      ''', [
      item.title,
      item.body,
      item.contentSha256,
      item.practice?.mode,
      steps,
      cachedAt,
      cacheId,
    ]);
  }

  Future<void> _savePreferenceRow(
    SqliteWriteContext transaction,
    PrayerReleasePreference preference,
  ) async {
    await transaction.execute('DELETE FROM prayer_release_preference_cache');
    await transaction.execute(
      '''
      INSERT INTO prayer_release_preference_cache(
        id, weekly_enabled, notification_enabled, time_zone, refreshed_at
      ) VALUES ('current', ?, ?, ?, ?)
      ''',
      [
        preference.weeklyEnabled ? 1 : 0,
        preference.notificationEnabled ? 1 : 0,
        preference.timeZone,
        _now().toUtc().toIso8601String(),
      ],
    );
  }

  /// Reads the mirrored ordered item metadata, keyed by release slug.
  ///
  /// Reading these outside the watched query keeps the watchable statement free
  /// of the item join; a write to either table re-emits the stream.
  Future<Map<String, List<PrayerReleaseItem>>> _itemsFor(
    List<String> slugs,
  ) async {
    if (slugs.isEmpty) return const {};

    final placeholders = List.filled(slugs.length, '?').join(', ');
    final rows = await database.getAll('''
      SELECT * FROM prayer_release_item_cache
      WHERE release_slug IN ($placeholders)
      ORDER BY release_slug ASC, sort_order ASC
      ''', slugs);

    final items = <String, List<PrayerReleaseItem>>{};
    for (final row in rows) {
      items.putIfAbsent(row['release_slug'] as String, () => []).add(
        PrayerReleaseItem(
          id: row['item_id'] as String,
          sortOrder: row['sort_order'] as int? ?? 0,
          kind: PrayerReleaseItemKindValue.fromWire(row['kind'] as String),
          libraryPrayerId: row['library_prayer_id'] as String,
          title: row['title'] as String?,
          hasAttentionPractice: row['has_attention_practice'] == 1,
          narrationAvailable: row['narration_available'] == 1,
        ),
      );
    }

    return items;
  }

  PrayerRelease _releaseFromRow(
    Map<String, dynamic> row, {
    List<PrayerReleaseItem> items = const [],
  }) {
    final localAddedAt = DateTime.tryParse(row['local_added_at'] as String? ?? '');
    final addedAt = DateTime.tryParse(row['added_at'] as String? ?? '') ?? localAddedAt;

    return PrayerRelease(
      id: row['id'] as String,
      slug: row['slug'] as String,
      title: row['title'] as String,
      discoveryLabel: row['discovery_label'] as String,
      discoveryDetail: row['discovery_detail'] as String,
      publishedAt: DateTime.tryParse(row['published_at'] as String? ?? ''),
      addedAt: addedAt,
      items: const [],
    );
  }
}
