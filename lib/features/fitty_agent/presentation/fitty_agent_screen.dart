import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_bloc.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_consent_screen.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_event.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_model_dialog.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_state.dart';
import 'package:opennutritracker/features/settings/settings_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FittyAgentScreen extends StatelessWidget {
  const FittyAgentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<FittyAgentBloc>()..add(const FittyAgentStarted()),
      child: const _FittyAgentView(),
    );
  }
}

class _FittyAgentView extends StatefulWidget {
  const _FittyAgentView();

  @override
  State<_FittyAgentView> createState() => _FittyAgentViewState();
}

class _FittyAgentViewState extends State<_FittyAgentView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.fittyAgentTitle),
        actions: [
          IconButton(
            tooltip: s.fittyAgentChooseModel,
            onPressed: () => FittyAgentModelDialog.show(context),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: s.fittyAgentClearChat,
            onPressed: () =>
                context.read<FittyAgentBloc>().add(const FittyAgentCleared()),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: BlocConsumer<FittyAgentBloc, FittyAgentState>(
        listener: (context, state) {
          if (state is FittyAgentReady) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_scrollController.hasClients) return;
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            });
          }
        },
        builder: (context, state) {
          if (state is FittyAgentNeedsSetup) {
            return _SetupPane(
              needsAiConfig: state.needsAiConfig,
              needsConsent: state.needsConsent,
              onConfigureAi: () {
                Navigator.of(context).pushNamed(
                  NavigationOptions.settingsRoute,
                  arguments: const SettingsScreenArguments(openAiAssist: true),
                );
              },
              onConsent: () async {
                final selection = await locator<AiCredentialStorage>()
                    .readSelection();
                final provider = selection?.provider ?? AiProvider.anthropic;
                if (!context.mounted) return;
                final ok = await FittyAgentConsentScreen.show(
                  context,
                  provider: provider,
                );
                if (ok && context.mounted) {
                  context.read<FittyAgentBloc>().add(
                    const FittyAgentConsentAccepted(),
                  );
                }
              },
            );
          }

          if (state is! FittyAgentReady) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Expanded(
                child: state.bubbles.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Dimens.spacing24),
                          child: Text(
                            s.fittyAgentEmptyHint,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(Dimens.spacing16),
                        itemCount: state.bubbles.length,
                        itemBuilder: (context, index) {
                          final bubble = state.bubbles[index];
                          return _Bubble(bubble: bubble);
                        },
                      ),
              ),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimens.spacing16,
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !state.sending,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submit(context),
                          decoration: InputDecoration(
                            hintText: s.fittyAgentInputHint,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: state.sending
                            ? null
                            : () => _submit(context),
                        icon: state.sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _submit(BuildContext context) {
    final text = _controller.text;
    _controller.clear();
    context.read<FittyAgentBloc>().add(FittyAgentMessageSubmitted(text));
  }
}

class _SetupPane extends StatelessWidget {
  const _SetupPane({
    required this.needsAiConfig,
    required this.needsConsent,
    required this.onConfigureAi,
    required this.onConsent,
  });

  final bool needsAiConfig;
  final bool needsConsent;
  final VoidCallback onConfigureAi;
  final VoidCallback onConsent;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.all(Dimens.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.fittyAgentSetupBody,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          if (needsAiConfig)
            FilledButton(
              onPressed: onConfigureAi,
              child: Text(s.fittyAgentConfigureAi),
            ),
          if (needsConsent) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onConsent,
              child: Text(s.fittyAgentReviewConsent),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.bubble});

  final AgentChatBubble bubble;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = bubble.fromUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bg = bubble.isToolActivity
        ? theme.colorScheme.surfaceContainerHighest
        : bubble.fromUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.secondaryContainer;
    final fg = bubble.fromUser
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSecondaryContainer;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SelectableText(
            bubble.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: fg,
              fontStyle: bubble.isToolActivity ? FontStyle.italic : null,
            ),
          ),
        ),
      ),
    );
  }
}
