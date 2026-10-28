import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/identity/chatgpt_link_client.dart';

typedef ChatgptCodeCopier = Future<void> Function(String code);

Future<void> _copyChatgptCode(String code) =>
    Clipboard.setData(ClipboardData(text: code));

class ChatgptLinkSection extends StatefulWidget {
  const ChatgptLinkSection({
    super.key,
    required this.getStatus,
    required this.createCode,
    required this.unlink,
    this.copyCode = _copyChatgptCode,
  });

  final Future<bool> Function() getStatus;
  final Future<ChatgptLinkCode> Function() createCode;
  final Future<bool> Function() unlink;
  final ChatgptCodeCopier copyCode;

  @override
  State<ChatgptLinkSection> createState() => _ChatgptLinkSectionState();
}

class _ChatgptLinkSectionState extends State<ChatgptLinkSection>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _working = false;
  bool? _linked;
  String? _notice;
  ChatgptLinkCode? _code;
  Timer? _expires;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _expires?.cancel();
    _code = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _hideCode();
    }
    if (state == AppLifecycleState.resumed && !_working) {
      _refresh();
    }
  }

  void _hideCode() {
    _expires?.cancel();
    if (mounted && _code != null) {
      setState(() => _code = null);
    }
  }

  Future<void> _refresh() async {
    if (_working) return;
    setState(() {
      _checking = true;
      _notice = null;
    });
    try {
      final linked = await widget.getStatus();
      if (!mounted) return;
      if (linked) _hideCode();
      setState(() => _linked = linked);
    } on ChatgptLinkException catch (error) {
      if (mounted) setState(() {
        _linked = null;
        _notice = error.message;
      });
    } catch (_) {
      if (mounted) setState(() {
        _linked = null;
        _notice = 'Could not check the ChatGPT connection.';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _generateCode() async {
    if (_working || _checking || _linked != false) return;
    _hideCode();
    setState(() {
      _working = true;
      _notice = null;
    });
    try {
      final link = await widget.createCode();
      if (!mounted) return;
      final remaining = link.expiresAt.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        setState(() => _notice = 'This code expired. Generate a new one.');
        return;
      }
      _expires?.cancel();
      _expires = Timer(remaining, () {
        if (mounted) setState(() {
          _code = null;
          _notice = 'The link code expired. Generate a new one.';
        });
      });
      setState(() => _code = link);
    } on ChatgptLinkException catch (error) {
      if (mounted) setState(() => _notice = error.message);
    } on StateError {
      if (mounted) setState(() {
        _notice = 'Connect SoulBuddy to the server and try again.';
      });
    } catch (_) {
      if (mounted) setState(() {
        _notice = 'Could not generate a link code. Try again.';
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _copy() async {
    final code = _code;
    if (code == null || !code.expiresAt.isAfter(DateTime.now())) {
      _hideCode();
      return;
    }
    try {
      await widget.copyCode(code.code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code copied. Keep it private.')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _notice = 'Could not copy this code.');
    }
  }

  Future<void> _disconnect() async {
    if (_working || _checking || _linked != true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove SoulBuddy access from ChatGPT?'),
        content: const Text(
          'This removes the account link. It will not delete your '
          'plans or end your ChatGPT or identity-provider session. '
          'You may need to disconnect there separately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep connection'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove access'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _working = true;
      _notice = null;
    });
    try {
      await widget.unlink();
      if (mounted) {
        _hideCode();
        setState(() {
          _linked = false;
          _notice = 'SoulBuddy access removed. Also disconnect in '
              'ChatGPT and end the provider application session.';
        });
      }
    } on ChatgptLinkException catch (error) {
      if (mounted) setState(() => _notice = error.message);
    } catch (_) {
      if (mounted) setState(() => _notice = 'Could not remove access.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'ChatGPT life planner',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Connect your verified SoulBuddy account to plan and '
              'reflect in ChatGPT. ChatGPT plans do not yet sync with '
              'Goals in this app.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (_checking)
              const Center(child: CircularProgressIndicator())
            else if (_linked == true) ...[
              const Text('Connected to your SoulBuddy account.'),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: _working ? null : _disconnect,
                child: const Text('Remove ChatGPT access'),
              ),
            ] else if (_linked == false) ...[
              const Text(
                '1. Verify your SoulBuddy email in Settings above.\n'
                '2. Create a private, one-time link code.\n'
                '3. Sign in to SoulBuddy in ChatGPT and choose '
                'Link existing account. Paste the code there.',
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _working ? null : _generateCode,
                icon: const Icon(Icons.link_outlined),
                label: Text(
                  _working ? 'Creating code…' :
                  (_code == null ? 'Create link code' : 'Replace link code'),
                ),
              ),
              if (_code case final link?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Private code · expires at '
                  '${MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(link.expiresAt.toLocal()),
                  )}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  link.code,
                  key: const Key('chatgpt-link-code'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy code'),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Share only with the authenticated SoulBuddy tool '
                  'in ChatGPT. Never send this code to another person.',
                ),
              ],
            ],
            if (_notice case final notice?) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                notice,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _working || _checking ? null : _refresh,
              child: const Text('Check connection'),
            ),
          ],
        ),
      ),
    );
  }
}
