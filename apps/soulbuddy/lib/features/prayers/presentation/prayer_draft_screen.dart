import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/design/app_spacing.dart';
import '../domain/prayer_generation_request.dart';
import '../providers/personal_prayer_providers.dart';
import '../providers/prayer_providers.dart';

class PrayerDraftScreen extends ConsumerStatefulWidget {
  const PrayerDraftScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<PrayerDraftScreen> createState() => _PrayerDraftScreenState();
}

class _PrayerDraftScreenState extends ConsumerState<PrayerDraftScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _actionController = TextEditingController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();
  final _actionFocus = FocusNode();
  String? _loadedRequestId;
  bool _actionRemoved = false;
  bool _pending = false;
  bool _allowPop = false;
  Timer? _persistTimer;

  @override
  void initState() {
    super.initState();
    for (final node in [_titleFocus, _bodyFocus, _actionFocus]) {
      node.addListener(_persistOnBlur);
    }
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    for (final node in [_titleFocus, _bodyFocus, _actionFocus]) {
      node.removeListener(_persistOnBlur);
      node.dispose();
    }
    _titleController.dispose();
    _bodyController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  void _persistOnBlur() {
    if (!_titleFocus.hasFocus &&
        !_bodyFocus.hasFocus &&
        !_actionFocus.hasFocus &&
        _loadedRequestId != null) {
      unawaited(_persistDraft());
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(
      prayerGenerationRequestProvider(widget.requestId),
    );
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave(result));
      },
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: request.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const _DraftMessage(
                  title: 'Prayer draft',
                  body: 'This draft could not be opened just now.',
                ),
                data: (value) => _content(value),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(PrayerGenerationRequest? request) {
    if (request == null) {
      return const _DraftMessage(
        title: 'Prayer draft',
        body: 'This draft is no longer available.',
      );
    }
    if (request.status == PrayerGenerationStatus.queued ||
        request.status == PrayerGenerationStatus.generating) {
      return _DraftMessage(
        title: 'Preparing your prayer',
        body: request.nextAttemptAt == null
            ? 'SoulBuddy will keep this request here while the draft is prepared.'
            : 'SoulBuddy will try again when a connection is available.',
        busy: request.status == PrayerGenerationStatus.generating,
      );
    }
    if (request.status == PrayerGenerationStatus.needsAttention) {
      return _DraftNeedsAttention(
        onRetry: _pending ? null : () => _prepareAnother(request),
      );
    }
    if (request.status != PrayerGenerationStatus.ready ||
        request.draftTitle == null ||
        request.draftBody == null) {
      return const _DraftMessage(
        title: 'Prayer draft',
        body: 'Prepare this draft when you are ready.',
      );
    }
    _loadControllers(request);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _pending ? null : _leave,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Prayers'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Prayer draft', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Read it slowly. Change any wording that does not help you pray truthfully.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (request.contexts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final item in request.contexts)
                Chip(
                  avatar: Icon(
                    item.type == PrayerContextType.encounter
                        ? Icons.bookmark_outline
                        : Icons.menu_book_outlined,
                    size: 18,
                  ),
                  label: Text(item.displayLabel),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          key: const Key('draft-title-field'),
          controller: _titleController,
          focusNode: _titleFocus,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Title'),
          onChanged: (_) => _schedulePersist(),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          key: const Key('draft-body-field'),
          controller: _bodyController,
          focusNode: _bodyFocus,
          minLines: 6,
          maxLines: 12,
          maxLength: 4000,
          decoration: const InputDecoration(labelText: 'Prayer'),
          onChanged: (_) => _schedulePersist(),
        ),
        if (!_actionRemoved) ...[
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: const Key('draft-action-field'),
            controller: _actionController,
            focusNode: _actionFocus,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Optional practice'),
            onChanged: (_) => _schedulePersist(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _pending
                  ? null
                  : () {
                      _actionController.clear();
                      setState(() => _actionRemoved = true);
                      unawaited(_persistDraft());
                    },
              child: const Text('Remove action'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _pending ? null : () => _accept(request, useToday: false),
          child: _pending ? const _PendingLabel() : const Text('Save prayer'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: _pending ? null : () => _accept(request, useToday: true),
          child: _pending ? const _PendingLabel() : const Text('Use today'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _pending ? null : () => _prepareAnother(request),
          child: _pending
              ? const _PendingLabel()
              : const Text('Prepare another draft'),
        ),
      ],
    );
  }

  void _loadControllers(PrayerGenerationRequest request) {
    if (_loadedRequestId == request.id) return;
    _loadedRequestId = request.id;
    _titleController.text = request.draftTitle ?? '';
    _bodyController.text = request.draftBody ?? '';
    _actionController.text = request.draftAction ?? '';
    _actionRemoved = request.draftAction == null;
  }

  Future<void> _persistDraft() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    final repository = await ref.read(
      prayerGenerationRepositoryProvider.future,
    );
    final current = await repository.watch(widget.requestId).first;
    if (current == null) return;
    await repository.update(
      current.copyWith(
        draftTitle: title,
        draftBody: body,
        draftAction: _actionRemoved ? null : _actionController.text.trim(),
        clearDraftAction:
            _actionRemoved || _actionController.text.trim().isEmpty,
      ),
    );
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(_persistDraft());
    });
  }

  Future<void> _accept(
    PrayerGenerationRequest request, {
    required bool useToday,
  }) async {
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      _showError('A title and prayer are needed before saving.');
      return;
    }
    setState(() => _pending = true);
    try {
      await _persistDraft();
      final personalRepository = await ref.read(
        personalPrayerRepositoryProvider.future,
      );
      final prayer = await personalRepository.accept(
        requestId: request.id,
        title: _titleController.text,
        body: _bodyController.text,
        action: _actionRemoved ? null : _actionController.text,
      );
      if (useToday) {
        final todayRepository = await ref.read(prayerRepositoryProvider.future);
        await todayRepository.selectForToday(
          prayer.reference,
          includeAction:
              !_actionRemoved && _actionController.text.trim().isNotEmpty,
        );
      }
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.go(useToday ? '/today' : '/prayers/saved/${prayer.id}');
      }
    } on Object {
      if (mounted) _showError('This prayer could not be saved just now.');
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _prepareAnother(PrayerGenerationRequest request) async {
    await _persistDraft();
    final changed =
        _titleController.text.trim() != request.generatedTitle ||
        _bodyController.text.trim() != request.generatedBody ||
        (_actionRemoved ? null : _actionController.text.trim()) !=
            request.generatedAction;
    if (changed && mounted) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace your edits?'),
          content: const Text(
            'Preparing another draft will replace the wording on this draft.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace draft'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }
    if (!mounted) return;
    setState(() => _pending = true);
    try {
      final repository = await ref.read(
        prayerGenerationRepositoryProvider.future,
      );
      await repository.queue(
        request.id,
        provider: request.consentedProvider ?? AppConfig.prayerDraftProvider,
        disclosureVersion:
            request.consentedDisclosureVersion ??
            AppConfig.prayerDraftDisclosureVersion,
      );
      final dispatcher = await ref.read(
        prayerGenerationDispatcherProvider.future,
      );
      unawaited(dispatcher.dispatch(request.id));
    } on Object {
      if (mounted) _showError('Another draft could not be prepared just now.');
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _leave([Object? result]) async {
    if (_allowPop) return;
    await _persistDraft();
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) await Navigator.of(context).maybePop(result);
  }
}

class _PendingLabel extends StatelessWidget {
  const _PendingLabel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _DraftMessage extends StatelessWidget {
  const _DraftMessage({
    required this.title,
    required this.body,
    this.busy = false,
  });

  final String title;
  final String body;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _DraftNeedsAttention extends StatelessWidget {
  const _DraftNeedsAttention({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Prayer draft',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'This draft needs attention before it can be prepared.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
