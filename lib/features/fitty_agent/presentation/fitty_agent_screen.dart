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
import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_bloc.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_consent_screen.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_event.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_model_dialog.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_state.dart';
import 'package:opennutritracker/features/settings/settings_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Limits for meal photos attached to a single Fitty Chat turn.
class FittyAgentPhotoLimits {
  /// Hard cap on how many photos one message can carry.
  static const maxCount = 10;

  /// Total encoded (pre-base64) bytes across all attached photos.
  /// Per-image encoding is already capped by [MealPhotoEncoder.maxBytes];
  /// this keeps a full batch of 10 inside a reasonable request size.
  static const maxTotalBytes = 10 * 1024 * 1024;
}

class FittyAgentScreen extends StatelessWidget {
  /// When true (bottom-nav tab), the screen still owns its Scaffold/AppBar
  /// because [MainScreen] hides the outer app bar on the chat tab.
  const FittyAgentScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<FittyAgentBloc>()..add(const FittyAgentStarted()),
      child: _FittyAgentView(embedded: embedded),
    );
  }
}

class _FittyAgentView extends StatefulWidget {
  const _FittyAgentView({required this.embedded});

  final bool embedded;

  @override
  State<_FittyAgentView> createState() => _FittyAgentViewState();
}

class _FittyAgentViewState extends State<_FittyAgentView> {
  static final _log = Logger('FittyAgentScreen');

  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  final List<AgentAttachedImage> _attachedImages = [];
  bool _attaching = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int get _attachedTotalBytes =>
      _attachedImages.fold(0, (sum, image) => sum + image.bytes.length);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
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
                    ? _EmptySuggestions(
                        onSelect: (prompt) {
                          context.read<FittyAgentBloc>().add(
                            FittyAgentMessageSubmitted(prompt),
                          );
                        },
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
              if (_attachedImages.isNotEmpty)
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    itemCount: _attachedImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final image = _attachedImages[index];
                      return _AttachedPhotoChip(
                        bytes: image.bytes,
                        onClear: state.sending || _attaching
                            ? null
                            : () => setState(() {
                                _attachedImages.removeAt(index);
                              }),
                      );
                    },
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
                        onPressed: state.sending ||
                                _attaching ||
                                _attachedImages.length >=
                                    FittyAgentPhotoLimits.maxCount
                            ? null
                            : () => _attachPhotos(context),
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

  Future<void> _attachPhotos(BuildContext context) async {
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
      final picker = ImagePicker();
      final List<XFile> picked;
      if (source == ImageSource.gallery) {
        final remaining =
            FittyAgentPhotoLimits.maxCount - _attachedImages.length;
        if (remaining <= 0) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                s.fittyAgentPhotoLimitReached(FittyAgentPhotoLimits.maxCount),
              ),
            ),
          );
          return;
        }
        picked = await picker.pickMultiImage(limit: remaining);
      } else {
        final single = await picker.pickImage(source: source);
        picked = single == null ? const [] : [single];
      }
      if (picked.isEmpty || !mounted) return;

      if (_attachedImages.length + picked.length >
          FittyAgentPhotoLimits.maxCount) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              s.fittyAgentPhotoLimitReached(FittyAgentPhotoLimits.maxCount),
            ),
          ),
        );
        return;
      }

      final selection = await locator<AiCredentialStorage>().readSelection();
      final provider = selection?.provider ?? AiProvider.anthropic;
      final format = MealPhotoFormat.forProvider(provider);
      final encoded = <AgentAttachedImage>[];
      var failed = 0;
      for (final file in picked) {
        final photo = await MealPhotoEncoder.encodeAndDiscardSource(
          file.path,
          format: format,
        );
        if (photo == null) {
          failed++;
          continue;
        }
        encoded.add(
          AgentAttachedImage(bytes: photo.bytes, mediaType: photo.mediaType),
        );
      }
      if (!mounted) return;

      final nextTotal =
          _attachedTotalBytes +
          encoded.fold<int>(0, (sum, image) => sum + image.bytes.length);
      if (nextTotal > FittyAgentPhotoLimits.maxTotalBytes) {
        messenger.showSnackBar(
          SnackBar(content: Text(s.fittyAgentPhotoTotalSizeLimit)),
        );
        return;
      }

      if (encoded.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(s.fittyAgentPhotoAttachFailed)),
        );
        return;
      }

      setState(() => _attachedImages.addAll(encoded));
      if (failed > 0) {
        messenger.showSnackBar(
          SnackBar(content: Text(s.fittyAgentPhotoAttachFailed)),
        );
      }
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
    final images = List<AgentAttachedImage>.from(_attachedImages);
    if (text.trim().isEmpty && images.isEmpty) return;
    _controller.clear();
    setState(() => _attachedImages.clear());
    context.read<FittyAgentBloc>().add(
      FittyAgentMessageSubmitted(text, images: images),
    );
  }
}

class _EmptySuggestions extends StatelessWidget {
  const _EmptySuggestions({required this.onSelect});

  final void Function(String prompt) onSelect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final prompts = [
      s.fittyAgentSuggestionPeriod,
      s.fittyAgentSuggestionPlan,
      s.fittyAgentSuggestionLeftovers,
    ];
    return ListView(
      padding: const EdgeInsets.all(Dimens.spacing24),
      children: [
        Text(
          s.fittyAgentEmptyHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: Dimens.spacing24),
        for (final prompt in prompts) ...[
          OutlinedButton(
            onPressed: () => onSelect(prompt),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: Text(prompt, textAlign: TextAlign.start),
          ),
          const SizedBox(height: Dimens.spacing12),
        ],
      ],
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
    final images = bubble.images.where((image) => image.isValid).toList();

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
              if (images.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final image in images)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          Uint8List.fromList(image.bytes),
                          width: images.length == 1 ? 120 : 72,
                          height: images.length == 1 ? 120 : 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
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
