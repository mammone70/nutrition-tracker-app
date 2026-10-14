import 'package:opennutritracker/features/add_meal/domain/meal_items_api.dart';
import 'package:opennutritracker/features/nutrition_label/domain/nutrition_label_entity.dart';

export 'package:opennutritracker/features/add_meal/domain/meal_interpreter_exception.dart';

/// Forced-tool name for reading a nutrition facts panel.
const nutritionLabelToolName = 'read_nutrition_label';

const nutritionLabelToolDescription =
    'Record the nutrition facts printed on the label in the photo.';

/// Prompt sent with the photograph. Short on purpose — the schema carries
/// the field list; this only says what the picture is for.
const nutritionLabelPhotoPrompt =
    'Read the nutrition facts panel in this photo.';

/// System prompt for label transcription.
///
/// Deliberately separate from meal-assist prompts: this path **is** allowed
/// to return nutrition numbers because they are printed on the package and
/// the user reviews them before save. Meal assist still must not invent
/// calories for a plate of food.
const nutritionLabelSystemPrompt = '''
You read a photograph of a packaged food's nutrition facts / nutrition
information panel and transcribe the printed numbers. You do not estimate
and you do not invent values that are not legible on the label.

Rules:
- Only fill a field when you can clearly read it on the panel.
- Omit a field rather than guessing.
- "basis" is "per_serving" when the panel's column is for one serving, or
  "per_100" when it is per 100 g or 100 ml.
- "serving_quantity" is the grams or millilitres of one serving when stated
  (e.g. "Serving size: 30 g" → 30). Omit when the panel does not say.
- "serving_unit" is "g" or "ml".
- Energy is always in kcal. If the panel only prints kJ, convert to kcal
  (divide by 4.184) and round to one decimal place.
- Macros and fibre/sugars/saturated fat are in grams.
- Sodium, calcium, iron, potassium and magnesium are in milligrams. If the
  panel prints salt in grams, convert sodium as salt_g × 400 (approx mg).
- Vitamin D and vitamin B12 are in micrograms (µg).
- "name" is the product name if it is visible near the panel; omit if not.
- "brands" is the brand if legible; omit if not.
- "barcode" only if a retail barcode number is clearly readable in the
  photo; omit otherwise.
- If the photo is not a nutrition label, return an object with basis
  "per_100" and no nutrient fields.''';

/// JSON Schema for the forced tool. Kept as a top-level constant so adding a
/// provider cannot quietly introduce a second label schema.
const nutritionLabelToolSchema = {
  'type': 'object',
  'properties': {
    'name': {'type': 'string'},
    'brands': {'type': 'string'},
    'barcode': {'type': 'string'},
    'serving_quantity': {'type': 'number'},
    'serving_unit': {
      'type': 'string',
      'enum': ['g', 'ml'],
    },
    'basis': {
      'type': 'string',
      'enum': ['per_serving', 'per_100'],
    },
    'energy_kcal': {'type': 'number'},
    'carbohydrates_g': {'type': 'number'},
    'fat_g': {'type': 'number'},
    'proteins_g': {'type': 'number'},
    'fiber_g': {'type': 'number'},
    'sugars_g': {'type': 'number'},
    'saturated_fat_g': {'type': 'number'},
    'sodium_mg': {'type': 'number'},
    'calcium_mg': {'type': 'number'},
    'iron_mg': {'type': 'number'},
    'potassium_mg': {'type': 'number'},
    'magnesium_mg': {'type': 'number'},
    'vitamin_d_ug': {'type': 'number'},
    'vitamin_b12_ug': {'type': 'number'},
  },
  'required': ['basis'],
  'additionalProperties': false,
};

/// One forced tool call that returns a transcribed nutrition label.
abstract interface class NutritionLabelApi {
  Future<NutritionLabelEntity> requestLabel({
    required MealPhotoContent content,
    required String system,
  });
}
