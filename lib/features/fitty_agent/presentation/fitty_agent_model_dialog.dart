import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/core/utils/ai_model_catalogue.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/fitty_agent/domain/fitty_agent_consent_storage.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Pick a Fitty Agent chat model without changing AI meal/photo assist.
class FittyAgentModelDialog extends StatefulWidget {
  const FittyAgentModelDialog({
    super.key,
    FittyAgentConsentStorage? agentSettings,
    AiCredentialStorage? credentials,
  }) : _agentSettings = agentSettings,
       _credentials = credentials;

  final FittyAgentConsentStorage? _agentSettings;
  final AiCredentialStorage? _credentials;

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const FittyAgentModelDialog(),
    );
  }

  @override
  State<FittyAgentModelDialog> createState() => _FittyAgentModelDialogState();
}

class _FittyAgentModelDialogState extends State<FittyAgentModelDialog> {
  late final FittyAgentConsentStorage _agentSettings =
      widget._agentSettings ?? locator<FittyAgentConsentStorage>();
  late final AiCredentialStorage _credentials =
      widget._credentials ?? locator<AiCredentialStorage>();

  AiProvider? _provider;
  AiModel? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final selection = await _credentials.readSelection();
    if (!mounted) return;
    if (selection == null) {
      setState(() {
        _provider = null;
        _selected = null;
        _loading = false;
      });
      return;
    }
    final stored = await _agentSettings.readModel(provider: selection.provider);
    final resolved = AiModelCatalogue.resolveForAgent(
      selection.provider,
      stored,
    );
    if (!mounted) return;
    setState(() {
      _provider = selection.provider;
      _selected = resolved;
      _loading = false;
    });
  }

  Future<void> _select(AiModel model) async {
    final provider = _provider;
    if (provider == null) return;
    await _agentSettings.writeModel(model.id, provider: provider);
    if (!mounted) return;
    setState(() => _selected = model);
  }

  String _noteLabel(S s, AiModelNote note) => switch (note) {
    AiModelNote.cheaper => s.aiAssistModelCheaperLabel,
    AiModelNote.moreItems => s.aiAssistModelMoreItemsLabel,
    AiModelNote.cheapest => s.aiAssistModelCheapestLabel,
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final provider = _provider;
    final models = provider == null
        ? const <AiModel>[]
        : AiModelCatalogue.forProvider(provider);
    final agentDefault = provider == null
        ? null
        : AiModelCatalogue.defaultForAgent(provider);

    return AlertDialog(
      title: Text(s.fittyAgentModelTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const SizedBox(
                height: 96,
                child: Center(child: CircularProgressIndicator()),
              )
            : provider == null
            ? Text(s.fittyAgentModelNeedsAiAssist)
            : models.isEmpty
            ? Text(s.fittyAgentModelUsesAssist)
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.fittyAgentModelBody,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    ...models.map((model) {
                      final isAgentDefault = model.id == agentDefault?.id;
                      return Semantics(
                        identifier: 'fitty-agent-model-${model.id}',
                        // ignore: deprecated_member_use
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          horizontalTitleGap: 0,
                          title: Text(
                            model.id,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              s.aiAssistServedByLabel(model.servedBy),
                              if (isAgentDefault)
                                s.fittyAgentModelRecommendedLabel
                              else if (model.note case final note?)
                                _noteLabel(s, note),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                          value: model.id,
                          // ignore: deprecated_member_use
                          groupValue: _selected?.id,
                          // ignore: deprecated_member_use
                          onChanged: (value) {
                            if (value == null) return;
                            _select(models.firstWhere((m) => m.id == value));
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.dialogOKLabel),
        ),
      ],
    );
  }
}
