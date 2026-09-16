import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Agreement that Fitty Agent may send diary, plans, and profile summaries
/// to the same LLM configured under AI meal assistance.
class FittyAgentConsentScreen extends StatelessWidget {
  const FittyAgentConsentScreen({super.key, required this.provider});

  final AiProvider provider;

  static Future<bool> show(
    BuildContext context, {
    required AiProvider provider,
  }) async =>
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => FittyAgentConsentScreen(provider: provider),
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge;

    return Scaffold(
      appBar: AppBar(title: Text(s.fittyAgentConsentTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(s.fittyAgentConsentBody(provider.name), style: body),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(s.fittyAgentConsentAgree),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(s.fittyAgentConsentDecline),
            ),
          ],
        ),
      ),
    );
  }
}
