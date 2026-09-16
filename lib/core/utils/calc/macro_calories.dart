/// Atwater 4/4/9 macro calorie helpers (ported from calorie-tracker shared).
const int proteinCaloriesPerG = 4;
const int carbsCaloriesPerG = 4;
const int fatCaloriesPerG = 9;
const int defaultMacroCaloriesTolerance = 1;

const String macroCaloriesMismatchMessage =
    'Calories must equal protein×4 + carbs×4 + fat×9 (within 1 cal)';

/// Calories implied by macro grams using the 4/4/9 rule.
int caloriesFromMacros(num proteinG, num fatG, num carbsG) {
  return (proteinG * proteinCaloriesPerG +
          carbsG * carbsCaloriesPerG +
          fatG * fatCaloriesPerG)
      .round();
}

bool macrosMatchCalories(
  num calories,
  num proteinG,
  num fatG,
  num carbsG, {
  int tolerance = defaultMacroCaloriesTolerance,
}) {
  final computed = caloriesFromMacros(proteinG, fatG, carbsG);
  return (computed - calories.round()).abs() <= tolerance;
}

String? macroCaloriesError(num calories, num proteinG, num fatG, num carbsG) {
  if (macrosMatchCalories(calories, proteinG, fatG, carbsG)) return null;
  final expected = caloriesFromMacros(proteinG, fatG, carbsG);
  return '$macroCaloriesMismatchMessage. Based on your macros, calories should be $expected.';
}
