import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/personal_prayer.dart';
import '../domain/prayer_session.dart';
import '../providers/prayer_practice_providers.dart';

class PrayerSessionActions extends ConsumerStatefulWidget {
  const PrayerSessionActions({required this.prayer, super.key});

  final PersonalPrayer prayer;

  @override
  ConsumerState<PrayerSessionActions> createState() =>
      _PrayerSessionActionsState();
}

class _PrayerSessionActionsState extends ConsumerState<PrayerSessionActions> {
  bool _saving = false;
  PrayerSession? _lastSession;
  Timer? _undoTimer;
  String? _error;

  @override
  void didUpdateWidget(covariant PrayerSessionActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prayer.id != widget.prayer.id ||
        oldWidget.prayer.currentRevisionId != widget.prayer.currentRevisionId) {
      _undoTimer?.cancel();
      _lastSession = null;
      _error = null;
    }
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(
      prayerSessionCountProvider(widget.prayer.currentRevisionId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Record that you prayed ${widget.prayer.title}',
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _saving ? null : _record,
            icon: const Icon(Icons.check),
            label: Text(_saving ? 'Recording...' : 'I prayed this'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        count.when(
          data: (value) => Text(
            value == 1
                ? '1 prayer time recorded'
                : '$value prayer times recorded',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        if (_lastSession != null)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _saving ? null : _undo,
              child: const Text('Undo'),
            ),
          ),
        if (_error != null)
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  Future<void> _record() async {
    if (_saving) return;
    final displayedPrayer = widget.prayer;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = await ref.read(
        prayerPracticeRepositoryProvider.future,
      );
      final timezoneName = await ref.read(prayerDeviceTimezoneProvider)();
      final session = await repository.recordSession(
        personalPrayerId: displayedPrayer.id,
        revisionId: displayedPrayer.currentRevisionId,
        timezone: timezoneName,
      );
      if (!mounted) return;
      _undoTimer?.cancel();
      _undoTimer = Timer(const Duration(minutes: 5), () {
        if (mounted) setState(() => _lastSession = null);
      });
      setState(() {
        _saving = false;
        _lastSession = session;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not record this prayer just now.';
        });
      }
    }
  }

  Future<void> _undo() async {
    final session = _lastSession;
    if (_saving || session == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = await ref.read(
        prayerPracticeRepositoryProvider.future,
      );
      await repository.retractSession(session.id);
      if (!mounted) return;
      _undoTimer?.cancel();
      setState(() {
        _saving = false;
        _lastSession = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not undo this prayer record just now.';
        });
      }
    }
  }
}
