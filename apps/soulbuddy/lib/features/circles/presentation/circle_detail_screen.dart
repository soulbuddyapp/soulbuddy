import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../domain/circle_message.dart';
import '../providers/circle_providers.dart';

class CircleDetailScreen extends ConsumerStatefulWidget {
  const CircleDetailScreen({required this.circleId, super.key});

  final String circleId;

  @override
  ConsumerState<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends ConsumerState<CircleDetailScreen> {
  final _messageController = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circle = ref.watch(circleProvider(widget.circleId));
    return circle.when(
      loading: () => const _CircleLoading(),
      error: (_, _) => _CircleUnavailable(
        onRetry: () => retryCircleProviders(ref, circleId: widget.circleId),
      ),
      data: (value) {
        if (value == null) return const _CircleUnavailable();
        return _buildConversation(context, value.name);
      },
    );
  }

  Widget _buildConversation(BuildContext context, String circleName) {
    final messages = ref.watch(circleMessagesProvider(widget.circleId));
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Back to Circles',
                            onPressed: () => context.go('/circles'),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              circleName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact =
                              constraints.maxWidth < 360 ||
                              MediaQuery.textScalerOf(context).scale(1) >= 1.5;
                          return Row(
                            children: [
                              const Expanded(child: _LocalMembershipLabel()),
                              if (compact) ...[
                                const _UnavailableCircleAction(
                                  icon: Icons.person_add_alt_outlined,
                                  label: 'Invite',
                                ),
                                const _UnavailableCircleAction(
                                  icon: Icons.share_outlined,
                                  label: 'Share',
                                ),
                              ] else ...[
                                const _UnavailableCircleAction(
                                  icon: Icons.person_add_alt_outlined,
                                  label: 'Invite',
                                  showLabel: true,
                                ),
                                const _UnavailableCircleAction(
                                  icon: Icons.share_outlined,
                                  label: 'Share',
                                  showLabel: true,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    messages.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, _) => Center(
                        child: OutlinedButton(
                          onPressed: () => retryCircleProviders(
                            ref,
                            circleId: widget.circleId,
                          ),
                          child: const Text('Open conversation again'),
                        ),
                      ),
                      data: (items) => items.isEmpty
                          ? const _EmptyConversation()
                          : _MessageList(messages: items),
                    ),
                  ],
                ),
              ),
              _MessageComposer(
                controller: _messageController,
                sending: _sending,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    setState(() => _sending = true);
    try {
      final repository = await ref.read(circleRepositoryProvider.future);
      await repository.sendMessage(widget.circleId, message);
      _messageController.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this message. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _CircleLoading extends StatelessWidget {
  const _CircleLoading();

  @override
  Widget build(BuildContext context) =>
      const SafeArea(child: Center(child: CircularProgressIndicator()));
}

class _CircleUnavailable extends StatelessWidget {
  const _CircleUnavailable({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                onRetry == null
                    ? 'Circle unavailable'
                    : 'Circle could not be opened',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                onRetry == null
                    ? 'This Circle is not available for this account or device.'
                    : 'Your saved conversation has not been changed.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (onRetry != null) ...[
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextButton(
                onPressed: () => context.go('/circles'),
                child: const Text('Back to Circles'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LocalMembershipLabel extends StatelessWidget {
  const _LocalMembershipLabel();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.lock_outline,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: AppSpacing.xs),
      const Expanded(child: Text('Only you · this device')),
    ],
  );
}

class _UnavailableCircleAction extends StatelessWidget {
  const _UnavailableCircleAction({
    required this.icon,
    required this.label,
    this.showLabel = false,
  });

  final IconData icon;
  final String label;
  final bool showLabel;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '$label will be available after secure sync is connected',
    child: showLabel
        ? TextButton.icon(onPressed: null, icon: Icon(icon), label: Text(label))
        : IconButton(onPressed: null, tooltip: label, icon: Icon(icon)),
  );
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      children: [
        Icon(
          Icons.forum_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Begin the conversation',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Write a prayer need, encouragement, or Scripture to keep here.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Invite and Share will appear after secure sync is connected.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});

  final List<CircleMessage> messages;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      children: [
        for (final (index, message) in messages.indexed) ...[
          Align(
            alignment: message.isMine
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: message.isMine
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppSpacing.componentRadius,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message.body),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Saved on this device',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (index != messages.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    ),
  );
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('circle-message-field'),
                controller: controller,
                enabled: !sending,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Write something to share here',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              key: const Key('send-circle-message'),
              tooltip: 'Save message',
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
            ),
          ],
        ),
      ),
    ),
  );
}
