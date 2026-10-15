import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/features/add_meal/domain/meal_items_api.dart';
import 'package:opennutritracker/features/add_meal/domain/meal_photo_interpreter.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/read_meal_photo_usecase.dart';
import 'package:opennutritracker/features/nutrition_label/domain/nutrition_label_api.dart';
import 'package:opennutritracker/features/nutrition_label/domain/nutrition_label_entity.dart';

/// Outcome of reading a nutrition facts photo.
sealed class NutritionLabelReadResult {
  const NutritionLabelReadResult();
}

final class NutritionLabelRead extends NutritionLabelReadResult {
  final NutritionLabelEntity label;

  const NutritionLabelRead(this.label);
}

final class NutritionLabelUnavailable extends NutritionLabelReadResult {
  const NutritionLabelUnavailable();
}

final class NutritionLabelEmpty extends NutritionLabelReadResult {
  const NutritionLabelEmpty();
}

final class NutritionLabelFailed extends NutritionLabelReadResult {
  final MealPhotoFailure failure;

  const NutritionLabelFailed(this.failure);
}

/// Reads a nutrition facts panel from a photograph via the user's AI
/// credentials — the same destinations meal-photo assist uses.
class ReadNutritionLabelUseCase {
  static final _log = Logger('ReadNutritionLabelUseCase');

  final AiCredentialStorage _credentials;
  final NutritionLabelApi Function(AiSelection selection) _apiFactory;

  ReadNutritionLabelUseCase(this._credentials, this._apiFactory);

  Future<NutritionLabelReadResult> read(MealPhoto photo) async {
    final selection = await _credentials.readSelection();
    if (selection == null) {
      return const NutritionLabelUnavailable();
    }

    try {
      final label = await _apiFactory(selection).requestLabel(
        content: MealPhotoContent(
          mediaType: photo.mediaType,
          base64Data: base64Encode(photo.bytes),
        ),
        system: nutritionLabelSystemPrompt,
      );
      if (!label.hasUsableNutrition) {
        return const NutritionLabelEmpty();
      }
      return NutritionLabelRead(label);
    } on MealInterpreterException catch (e) {
      _log.info('Nutrition label read failed: ${e.reason}');
      return NutritionLabelFailed(switch (e.failure) {
        MealInterpreterFailure.auth => MealPhotoFailure.auth,
        MealInterpreterFailure.rejected => MealPhotoFailure.rejectedImage,
        MealInterpreterFailure.unsupported => MealPhotoFailure.unsupported,
        MealInterpreterFailure.billing => MealPhotoFailure.billing,
        MealInterpreterFailure.insecureDestination =>
          MealPhotoFailure.insecureDestination,
        MealInterpreterFailure.timeout ||
        MealInterpreterFailure.transient => MealPhotoFailure.transient,
      });
    } catch (e, stackTrace) {
      _log.severe('Nutrition label read failed unexpectedly', e, stackTrace);
      return const NutritionLabelFailed(MealPhotoFailure.transient);
    }
  }
}
