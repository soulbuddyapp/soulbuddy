import 'dart:async';

import 'package:soulbuddy/features/prayers/data/prayer_release_repository.dart';
import 'package:soulbuddy/features/prayers/domain/affirmation_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_release.dart';

/// An in-memory release repository for widget tests.
class InMemoryPrayerReleaseRepository implements PrayerReleaseRepository {
  InMemoryPrayerReleaseRepository({
    List<PrayerRelease> releases = const [],
    Map<String, List<PrayerReleaseItemContent>> content = const {},
    this.preference = const PrayerReleasePreference(),
  }) : _releases = [...releases],
       _content = {...content};

  List<PrayerRelease> _releases;
  final Map<String, List<PrayerReleaseItemContent>> _content;
  PrayerReleasePreference preference;

  final savedSessions = <AffirmationPrayerSession>[];
  var refreshCount = 0;
  var failRefresh = false;
  var failAdd = false;
  var failPreferenceSave = false;

  final _releasesController = StreamController<List<PrayerRelease>>.broadcast();
  final _addedController = StreamController<List<PrayerRelease>>.broadcast();
  final _preferenceController =
      StreamController<PrayerReleasePreference>.broadcast();

  /// Replaces a release in the fake catalogue, as discovery or an add would.
  void putRelease(
    PrayerRelease release, {
    List<PrayerReleaseItemContent>? items,
  }) {
    _releases = [
      release,
      ..._releases.where((existing) => existing.slug != release.slug),
    ];
    if (items != null) _content[release.slug] = items;
    _emit();
  }

  void _emit() {
    if (_releasesController.isClosed) return;
    _releasesController.add(_releases);
    _addedController.add(_addedReleases());
  }

  List<PrayerRelease> _addedReleases() =>
      _releases.where((release) => release.added).toList(growable: false);

  PrayerRelease? _bySlug(String slug) {
    for (final release in _releases) {
      if (release.slug == slug) return release;
    }

    return null;
  }

  /// The first stored item of a release, whether or not it has been added.
  PrayerReleaseItemContent? _storedFirst(String slug) {
    final items = _content[slug];
    return (items == null || items.isEmpty) ? null : items.first;
  }

  /// The first item a reader may see, which requires an explicit add.
  PrayerReleaseItemContent? _contentFor(String slug) {
    if (_bySlug(slug)?.added != true) return null;

    return _storedFirst(slug);
  }

  PrayerReleaseItemContent? _contentForPrayer(String libraryPrayerId) {
    for (final release in _releases) {
      if (!release.added) continue;
      for (final item in _content[release.slug] ?? const []) {
        if (item.libraryPrayerId == libraryPrayerId) return item;
      }
    }

    return null;
  }

  /// A stream that emits the current state first, then every later change of
  /// [source] mapped through [select].
  Stream<T> _seeded<S, T>(
    Stream<S> source,
    T Function() current,
    T Function(S) select,
  ) {
    late StreamController<T> controller;
    StreamSubscription<S>? subscription;

    controller = StreamController<T>(
      onListen: () {
        controller.add(current());
        subscription = source.listen(
          (event) => controller.add(select(event)),
          onError: controller.addError,
        );
      },
      onCancel: () => subscription?.cancel(),
    );

    return controller.stream;
  }

  @override
  Stream<List<PrayerRelease>> watchAddedReleases() =>
      _seeded(_addedController.stream, _addedReleases, (value) => value);

  @override
  Stream<List<PrayerRelease>> watchReleases() => _seeded(
    _releasesController.stream,
    () => List.unmodifiable(_releases),
    (value) => value,
  );

  @override
  Stream<PrayerRelease?> watchRelease(String slug) => _seeded(
    _releasesController.stream,
    () => _bySlug(slug),
    (_) => _bySlug(slug),
  );

  /// Content is only readable once the collection has been added, mirroring the
  /// server's access boundary.
  @override
  Stream<List<PrayerReleaseItemContent>> watchReleaseContent(String slug) =>
      _seeded(
        _releasesController.stream,
        () => _contentFor(slug) == null
            ? const <PrayerReleaseItemContent>[]
            : List.unmodifiable(_content[slug] ?? const []),
        (_) => _contentFor(slug) == null
            ? const <PrayerReleaseItemContent>[]
            : List.unmodifiable(_content[slug] ?? const []),
      );

  @override
  Stream<PrayerReleaseItemContent?> watchContentForPrayer(
    String libraryPrayerId,
  ) => _seeded(
    _releasesController.stream,
    () => _contentForPrayer(libraryPrayerId),
    (_) => _contentForPrayer(libraryPrayerId),
  );

  @override
  Stream<PrayerReleasePreference> watchPreference() => _seeded(
    _preferenceController.stream,
    () => preference,
    (value) => value,
  );

  @override
  Future<void> refresh() async {
    refreshCount++;
    if (failRefresh) throw StateError('offline');
    _emit();
  }

  @override
  Future<void> retry() => refresh();

  @override
  Future<PrayerReleaseItemContent> addRelease(String slug) async {
    if (failAdd) throw StateError('offline');

    final release = _bySlug(slug);
    if (release == null) throw StateError('unknown release');
    final first = _storedFirst(slug);
    if (first == null) throw StateError('release has no content');

    // A repeated add is the same outcome and keeps the original date.
    if (!release.added) {
      putRelease(
        PrayerRelease(
          id: release.id,
          slug: release.slug,
          title: release.title,
          discoveryLabel: release.discoveryLabel,
          discoveryDetail: release.discoveryDetail,
          publishedAt: release.publishedAt,
          addedAt: DateTime.utc(2026, 10, 6, 9),
          items: release.items,
        ),
      );
    }

    return first;
  }

  @override
  Future<void> savePreference(PrayerReleasePreference value) async {
    if (failPreferenceSave) throw StateError('offline');
    preference = value;
    if (!_preferenceController.isClosed) _preferenceController.add(value);
  }

  @override
  Future<void> saveAffirmationSession(AffirmationPrayerSession session) async {
    savedSessions.add(session);
  }

  Future<void> dispose() async {
    await _releasesController.close();
    await _addedController.close();
    await _preferenceController.close();
  }
}
