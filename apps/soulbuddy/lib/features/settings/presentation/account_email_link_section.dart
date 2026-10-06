import 'package:flutter/material.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/identity/account_email_link_client.dart';

class AccountEmailLinkSection extends StatefulWidget {
  const AccountEmailLinkSection({super.key, required this.requestLink});

  final Future<AccountEmailChallenge> Function(String email) requestLink;

  @override
  State<AccountEmailLinkSection> createState() =>
      _AccountEmailLinkSectionState();
}

class _AccountEmailLinkSectionState extends State<AccountEmailLinkSection> {
  final _emailController = TextEditingController();
  bool _sending = false;
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Email',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _emailController,
              enabled: !_sending,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email address'),
              onSubmitted: (_) => _requestLink(),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _sending ? null : _requestLink,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify email'),
            ),
            if (_notice case final notice?) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                notice,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _requestLink() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _notice = null;
    });
    try {
      await widget.requestLink(_emailController.text);
      if (mounted) setState(() => _notice = 'Verification link sent.');
    } on AccountEmailLinkException catch (error) {
      if (mounted) setState(() => _notice = error.message);
    } on StateError {
      if (mounted) {
        setState(() => _notice = 'Email verification is unavailable.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notice = 'The verification email could not be sent.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
