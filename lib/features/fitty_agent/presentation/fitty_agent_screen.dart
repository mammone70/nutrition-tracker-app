import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/util/meal_photo_encoder.dart';
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
  static final _log = Logger('FittyAgentScreen');

  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<int>? _attachedImageBytes;
  String? _attachedImageMediaType;
  bool _attaching = false;

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
              if (_attachedImageBytes != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _AttachedPhotoChip(
                      bytes: _attachedImageBytes!,
                      onClear: state.sending || _attaching
                          ? null
                          : () => setState(() {
                              _attachedImageBytes = null;
                              _attachedImageMediaType = null;
                            }),
                    ),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: s.fittyAgentAttachPhoto,
                        onPressed: state.sending || _attaching
                            ? null
                            : () => _attachPhoto(context),
                        icon: _attaching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined),
                      ),
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
                      const SizedBox(width: 4),
                      IconButton.filled(
                        onPressed: state.sending || _attaching
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

  Future<void> _attachPhoto(BuildContext context) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(s.mealImageTakePhoto),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(s.mealImagePickFromGallery),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _attaching = true);
    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null || !mounted) return;

      final selection = await locator<AiCredentialStorage>().readSelection();
      final provider = selection?.provider ?? AiProvider.anthropic;
      final photo = await MealPhotoEncoder.encodeAndDiscardSource(
        picked.path,
        format: MealPhotoFormat.forProvider(provider),
      );
      if (!mounted) return;
      if (photo == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(s.fittyAgentPhotoAttachFailed)),
        );
        return;
      }
      setState(() {
        _attachedImageBytes = photo.bytes;
        _attachedImageMediaType = photo.mediaType;
      });
    } catch (e, st) {
      _log.warning('Attaching Fitty Agent photo failed', e, st);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(s.fittyAgentPhotoAttachFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  void _submit(BuildContext context) {
    final text = _controller.text;
    final imageBytes = _attachedImageBytes;
    final imageMediaType = _attachedImageMediaType;
    if (text.trim().isEmpty && imageBytes == null) return;
    _controller.clear();
    setState(() {
      _attachedImageBytes = null;
      _attachedImageMediaType = null;
    });
    context.read<FittyAgentBloc>().add(
      FittyAgentMessageSubmitted(
        text,
        imageBytes: imageBytes,
        imageMediaType: imageMediaType,
      ),
    );
  }
}

class _AttachedPhotoChip extends StatelessWidget {
  const _AttachedPhotoChip({required this.bytes, required this.onClear});

  final List<int> bytes;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 2, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                Uint8List.fromList(bytes),
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bubble.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    Uint8List.fromList(bubble.imageBytes!),
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SelectableText(
                bubble.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontStyle: bubble.isToolActivity ? FontStyle.italic : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
