import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/core/utils/ai_model_catalogue.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/meal_photo_interpreter.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/read_meal_photo_usecase.dart';
import 'package:opennutritracker/features/add_meal/util/meal_photo_encoder.dart';
import 'package:opennutritracker/features/nutrition_label/domain/nutrition_label_entity.dart';
import 'package:opennutritracker/features/nutrition_label/domain/usecase/read_nutrition_label_usecase.dart';
import 'package:opennutritracker/features/settings/settings_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

final _log = Logger('NutritionLabelCapture');

/// Shared camera → encode → AI-read flow for a nutrition facts panel.
///
/// Returns the transcribed label, or null when the user cancelled or the
/// read failed (failures are shown as snackbars / dialogs here).
class NutritionLabelCapture {
  NutritionLabelCapture._();

  /// Whether AI credentials are configured enough to attempt a label photo.
  static Future<bool> isAvailable() async {
    final selection = await locator<AiCredentialStorage>().readSelection();
    return selection != null;
  }

  /// Opens disclosure → camera → AI read. Shows errors in [context].
  static Future<NutritionLabelEntity?> capture(BuildContext context) async {
    final credentials = locator<AiCredentialStorage>();
    final selection = await credentials.readSelection();
    if (!context.mounted) return null;

    if (selection == null) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(S.of(dialogContext).nutritionLabelNeedsAiTitle),
          content: Text(S.of(dialogContext).nutritionLabelNeedsAiContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(S.of(dialogContext).dialogCancelLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(S.of(dialogContext).settingsLabel),
            ),
          ],
        ),
      );
      if (openSettings == true && context.mounted) {
        await Navigator.of(context).pushNamed(
          NavigationOptions.settingsRoute,
          arguments: const SettingsScreenArguments(openAiAssist: true),
        );
      }
      return null;
    }

    final destinationName = _destinationName(context, selection);
    final disclosure = switch (selection.provider) {
      AiProvider.anthropic => S.of(context).nutritionLabelDisclosureAnthropic,
      AiProvider.openrouter =>
        S.of(context).nutritionLabelDisclosureOpenRouter(destinationName),
      AiProvider.openai => S.of(context).nutritionLabelDisclosureOpenAI,
      AiProvider.ownServer =>
        S.of(context).nutritionLabelDisclosureOwnServer(destinationName),
    };

    final shouldOpenCamera = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '$disclosure '
                '${S.of(sheetContext).bulkAddPhotoDisclosureCommon}\n\n'
                '${S.of(sheetContext).aiAssistExperimentalNote}',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ),
            Semantics(
              identifier: 'nutrition-label-photo-camera',
              child: ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: Text(S.of(sheetContext).nutritionLabelTakePhoto),
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
            ),
            Semantics(
              identifier: 'nutrition-label-photo-gallery',
              child: ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(S.of(sheetContext).mealImagePickFromGallery),
                onTap: () => Navigator.of(sheetContext).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
    if (shouldOpenCamera == null || !context.mounted) return null;

    final source = shouldOpenCamera ? ImageSource.camera : ImageSource.gallery;

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source);
    } catch (e, stackTrace) {
      _log.warning('Opening nutrition label picker failed', e, stackTrace);
      if (!context.mounted) return null;
      _showMessage(context, S.of(context).nutritionLabelCameraFailed);
      return null;
    }
    if (picked == null || !context.mounted) return null;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(child: Text(S.of(dialogContext).nutritionLabelReading)),
            ],
          ),
        ),
      ),
    );

    MealPhoto? photo;
    try {
      photo = await MealPhotoEncoder.encodeAndDiscardSource(
        picked.path,
        format: MealPhotoFormat.forProvider(selection.provider),
      );
    } catch (e, stackTrace) {
      _log.warning('Encoding nutrition label photo failed', e, stackTrace);
    }

    if (!context.mounted) return null;
    Navigator.of(context, rootNavigator: true).pop(); // progress dialog

    if (photo == null) {
      _showMessage(context, S.of(context).nutritionLabelUnreadable);
      return null;
    }

    final result = await locator<ReadNutritionLabelUseCase>().read(photo);
    if (!context.mounted) return null;

    return switch (result) {
      NutritionLabelRead(:final label) => label,
      NutritionLabelUnavailable() => () {
        _showMessage(context, S.of(context).nutritionLabelNeedsAiContent);
        return null;
      }(),
      NutritionLabelEmpty() => () {
        _showMessage(context, S.of(context).nutritionLabelNoFacts);
        return null;
      }(),
      NutritionLabelFailed(:final failure) => () {
        _showMessage(context, _failureMessage(context, failure));
        return null;
      }(),
    };
  }

  static String _destinationName(BuildContext context, AiSelection selection) {
    final model = AiModelCatalogue.resolve(
      selection.provider,
      selection.modelId,
    );
    if (selection.provider == AiProvider.ownServer) {
      final host = Uri.tryParse(selection.endpoint ?? '')?.host;
      return host?.isNotEmpty == true ? host! : selection.endpoint ?? '';
    }
    if (selection.provider == AiProvider.openrouter) {
      return model?.servedBy ?? 'OpenRouter';
    }
    return model?.servedBy ?? selection.provider.name;
  }

  static String _failureMessage(
    BuildContext context,
    MealPhotoFailure failure,
  ) {
    final s = S.of(context);
    return switch (failure) {
      MealPhotoFailure.billing => s.bulkAddPhotoNoCreditLabel,
      MealPhotoFailure.auth => s.bulkAddPhotoKeyRejectedLabel,
      MealPhotoFailure.rejectedImage => s.nutritionLabelUnreadable,
      MealPhotoFailure.unsupported => s.bulkAddPhotoUnsupportedLabel,
      MealPhotoFailure.insecureDestination => s.bulkAddPhotoFailedLabel,
      MealPhotoFailure.transient => s.nutritionLabelFailed,
    };
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
