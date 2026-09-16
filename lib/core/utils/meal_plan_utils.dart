import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_plan_entry_entity.dart';

const List<String> weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const int minMealsPerDay = 1;
const int maxMealsPerDay = 10;
const int defaultMealCount = 3;

const List<String> defaultMealNames = [
  'Breakfast',
  'Lunch',
  'Dinner',
  'Snack',
  'Meal 5',
  'Meal 6',
  'Meal 7',
  'Meal 8',
  'Meal 9',
  'Meal 10',
];

/// 0 = Monday … 6 = Sunday (matches calorie-tracker).
int dayOfWeekFromDate(DateTime date) {
  // Dart: Monday=1 … Sunday=7
  return date.weekday - 1;
}

int dayOfWeekFromDateString(String dateStr) {
  final parts = dateStr.split('-').map(int.parse).toList();
  return dayOfWeekFromDate(DateTime(parts[0], parts[1], parts[2], 12));
}

String defaultMealName(int mealIndex) {
  if (mealIndex >= 0 && mealIndex < defaultMealNames.length) {
    return defaultMealNames[mealIndex];
  }
  return 'Meal ${mealIndex + 1}';
}

EffectiveMacroTarget resolveEffectiveMacroTarget({
  required String date,
  MacroTargetEntity? override,
  WeeklyMacroTargetEntity? weekly,
}) {
  if (override != null) {
    return EffectiveMacroTarget(
      targetDate: date,
      calories: override.calories,
      proteinG: override.proteinG,
      fatG: override.fatG,
      carbsG: override.carbsG,
      source: MacroTargetSource.override,
      overrideId: override.id,
    );
  }

  if (weekly != null) {
    return EffectiveMacroTarget(
      targetDate: date,
      calories: weekly.calories,
      proteinG: weekly.proteinG,
      fatG: weekly.fatG,
      carbsG: weekly.carbsG,
      source: MacroTargetSource.weekly,
      weeklyDayOfWeek: weekly.dayOfWeek,
    );
  }

  return EffectiveMacroTarget(
    targetDate: date,
    calories: 0,
    proteinG: 0,
    fatG: 0,
    carbsG: 0,
    source: MacroTargetSource.none,
  );
}

EffectiveMealPlan resolveEffectiveMealPlan({
  required String date,
  required List<DayMealEntity> dayMeals,
  required List<MealPlanEntryEntity> dateEntries,
  required List<WeeklyMealEntity> weeklyMeals,
  required List<WeeklyMealPlanEntryEntity> weeklyEntries,
}) {
  if (dayMeals.isNotEmpty || dateEntries.isNotEmpty) {
    return EffectiveMealPlan(
      source: MealPlanSource.override,
      meals: _buildMealBlocks(
        meals: dayMeals
            .map(
              (m) => (
                id: m.id,
                mealIndex: m.mealIndex,
                name: m.name,
                mealTime: m.mealTime,
              ),
            )
            .toList(),
        entries: dateEntries
            .map(
              (e) => (
                id: e.id,
                mealId: e.dayMealId,
                foodId: e.foodId,
                foodName: e.foodName,
                brand: e.brand,
                caloriesPer100: e.caloriesPer100,
                proteinPer100: e.proteinPer100,
                fatPer100: e.fatPer100,
                carbsPer100: e.carbsPer100,
                quantity: e.quantity,
                unit: e.unit,
              ),
            )
            .toList(),
        source: MealPlanSource.override,
      ),
    );
  }

  final dayOfWeek = dayOfWeekFromDateString(date);
  final templateMeals = weeklyMeals
      .where((m) => m.dayOfWeek == dayOfWeek)
      .toList();

  if (templateMeals.isEmpty && weeklyEntries.isEmpty) {
    return const EffectiveMealPlan(source: MealPlanSource.none, meals: []);
  }

  final mealIds = templateMeals.map((m) => m.id).toSet();
  final templateEntries = weeklyEntries
      .where((e) => mealIds.contains(e.weeklyMealId))
      .toList();

  return EffectiveMealPlan(
    source: MealPlanSource.weekly,
    meals: _buildMealBlocks(
      meals: templateMeals
          .map(
            (m) => (
              id: m.id,
              mealIndex: m.mealIndex,
              name: m.name,
              mealTime: m.mealTime,
            ),
          )
          .toList(),
      entries: templateEntries
          .map(
            (e) => (
              id: e.id,
              mealId: e.weeklyMealId,
              foodId: e.foodId,
              foodName: e.foodName,
              brand: e.brand,
              caloriesPer100: e.caloriesPer100,
              proteinPer100: e.proteinPer100,
              fatPer100: e.fatPer100,
              carbsPer100: e.carbsPer100,
              quantity: e.quantity,
              unit: e.unit,
            ),
          )
          .toList(),
      source: MealPlanSource.weekly,
    ),
  );
}

List<EffectiveMealBlock> _buildMealBlocks({
  required List<({String id, int mealIndex, String name, String? mealTime})>
  meals,
  required List<
    ({
      String id,
      String mealId,
      String foodId,
      String foodName,
      String? brand,
      double caloriesPer100,
      double proteinPer100,
      double fatPer100,
      double carbsPer100,
      double quantity,
      String unit,
    })
  >
  entries,
  required MealPlanSource source,
}) {
  final sorted = [...meals]..sort((a, b) => a.mealIndex.compareTo(b.mealIndex));
  final byMeal = <String, List<MealPlanFoodEntry>>{};
  for (final entry in entries) {
    byMeal
        .putIfAbsent(entry.mealId, () => [])
        .add(
          MealPlanFoodEntry(
            id: entry.id,
            foodId: entry.foodId,
            foodName: entry.foodName,
            brand: entry.brand,
            caloriesPer100: entry.caloriesPer100,
            proteinPer100: entry.proteinPer100,
            fatPer100: entry.fatPer100,
            carbsPer100: entry.carbsPer100,
            quantity: entry.quantity,
            unit: entry.unit,
          ),
        );
  }

  return sorted
      .map(
        (meal) => EffectiveMealBlock(
          id: meal.id,
          mealIndex: meal.mealIndex,
          name: meal.name,
          mealTime: meal.mealTime,
          source: source,
          entries: byMeal[meal.id] ?? const [],
        ),
      )
      .toList();
}
