import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:uuid/uuid.dart';

/// Maps OpenNutriTracker diary rows onto calorie-tracker sync payloads.
class CalorieTrackerSyncMapper {
  static const _uuid = Uuid();

  /// Deterministic food UUID so the same product reuses one remote food row.
  static String foodIdForMeal(MealEntity meal) {
    final key = meal.code?.trim().isNotEmpty == true
        ? 'code:${meal.code!.trim()}'
        : 'name:${meal.name ?? 'unknown'}:${meal.brands ?? ''}';
    return _uuid.v5(Namespace.url.value, 'opennutri-food:$key');
  }

  static String foodIdForManual({
    required String name,
    String? brand,
    required double caloriesPer100,
    required double proteinPer100,
    required double fatPer100,
    required double carbsPer100,
  }) {
    final key =
        'manual:$name:${brand ?? ''}:$caloriesPer100:$proteinPer100:$fatPer100:$carbsPer100';
    return _uuid.v5(Namespace.url.value, 'opennutri-food:$key');
  }

  /// Deterministic day-meal UUID for (date, meal slot).
  static String dayMealIdFor(DateTime date, IntakeTypeEntity type) {
    return _uuid.v5(
      Namespace.url.value,
      'opennutri-daymeal:${date.toParsedDay()}:${type.name}',
    );
  }

  static int mealIndexFor(IntakeTypeEntity type) {
    switch (type) {
      case IntakeTypeEntity.breakfast:
        return 0;
      case IntakeTypeEntity.lunch:
        return 1;
      case IntakeTypeEntity.dinner:
        return 2;
      case IntakeTypeEntity.snack:
        return 3;
    }
  }

  static String foodSourceFor(MealEntity meal) {
    final source = meal.source.name.toLowerCase();
    if (source.contains('off')) return 'open_food_facts';
    if (source.contains('fdc')) return 'usda';
    return 'user';
  }

  static Map<String, dynamic> foodPayload(MealEntity meal) {
    final n = meal.nutriments;
    final calories = (n.energyKcal100 ?? 0).clamp(0, double.infinity);
    final protein = (n.proteins100 ?? 0).clamp(0, double.infinity);
    final fat = (n.fat100 ?? 0).clamp(0, double.infinity);
    final carbs = (n.carbohydrates100 ?? 0).clamp(0, double.infinity);
    // calorie-tracker rejects macros that cannot explain calories. Prefer the
    // stated energy; if missing, derive a Atwater estimate so create succeeds.
    final kcal = calories > 0
        ? calories.toDouble()
        : (protein * 4 + carbs * 4 + fat * 9).toDouble();

    return {
      'name': meal.name?.trim().isNotEmpty == true ? meal.name!.trim() : 'Food',
      if (meal.brands != null && meal.brands!.trim().isNotEmpty)
        'brand': meal.brands!.trim(),
      'source': foodSourceFor(meal),
      if (meal.code != null && meal.code!.trim().isNotEmpty)
        'externalId': meal.code!.trim(),
      'nutrientsPer100g': {
        'calories': kcal,
        'protein': protein.toDouble(),
        'fat': fat.toDouble(),
        'carbs': carbs.toDouble(),
      },
    };
  }

  static Map<String, dynamic> foodPayloadFromPlanEntry({
    required String foodName,
    String? brand,
    required double caloriesPer100,
    required double proteinPer100,
    required double fatPer100,
    required double carbsPer100,
  }) {
    return {
      'name': foodName.trim().isNotEmpty ? foodName.trim() : 'Food',
      if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
      'source': 'user',
      'nutrientsPer100g': {
        'calories': caloriesPer100,
        'protein': proteinPer100,
        'fat': fatPer100,
        'carbs': carbsPer100,
      },
    };
  }

  static Map<String, dynamic> dayMealPayload({
    required DateTime date,
    required IntakeTypeEntity type,
  }) {
    return {
      'planDate': date.toParsedDay(),
      'mealIndex': mealIndexFor(type),
      'name': type.name,
      'mealTime': null,
    };
  }

  static Map<String, dynamic> dayMealEntityPayload(DayMealEntity meal) {
    return {
      'planDate': meal.planDate,
      'mealIndex': meal.mealIndex,
      'name': meal.name,
      'mealTime': meal.mealTime,
    };
  }

  static Map<String, dynamic> foodLogPayload({
    required IntakeEntity intake,
    required String foodId,
    required String dayMealId,
  }) {
    return {
      'loggedAt': intake.dateTime.toUtc().toIso8601String(),
      'dayMealId': dayMealId,
      'foodId': foodId,
      'quantity': intake.amount,
      'unit': intake.unit.isEmpty ? 'g' : intake.unit,
      'status': 'confirmed',
    };
  }

  static Map<String, dynamic> bodyWeightPayload({
    required DateTime date,
    required double weightKg,
    String? note,
  }) {
    return {
      'loggedOn': date.toParsedDay(),
      'weight': weightKg,
      'unit': 'kg',
      'notes': ?note,
    };
  }

  static Map<String, dynamic> waistCircumferencePayload({
    required DateTime date,
    required double inches,
    String? note,
  }) {
    return {
      'loggedOn': date.toParsedDay(),
      'inches': inches,
      'notes': ?note,
    };
  }

  static Map<String, dynamic> weeklyMacroTargetPayload(
    WeeklyMacroTargetEntity target,
  ) {
    return {
      'dayOfWeek': target.dayOfWeek,
      'calories': target.calories,
      'proteinG': target.proteinG,
      'fatG': target.fatG,
      'carbsG': target.carbsG,
    };
  }

  static Map<String, dynamic> macroTargetPayload(MacroTargetEntity target) {
    return {
      'targetDate': target.targetDate,
      'calories': target.calories,
      'proteinG': target.proteinG,
      'fatG': target.fatG,
      'carbsG': target.carbsG,
    };
  }

  static Map<String, dynamic> weeklyMealPayload(WeeklyMealEntity meal) {
    return {
      'dayOfWeek': meal.dayOfWeek,
      'mealIndex': meal.mealIndex,
      'name': meal.name,
      'mealTime': meal.mealTime,
    };
  }

  static Map<String, dynamic> weeklyMealPlanEntryPayload(
    WeeklyMealPlanEntryEntity entry,
  ) {
    return {
      'weeklyMealId': entry.weeklyMealId,
      'foodId': entry.foodId,
      'quantity': entry.quantity,
      'unit': entry.unit.isEmpty ? 'g' : entry.unit,
    };
  }

  static Map<String, dynamic> mealPlanEntryPayload(MealPlanEntryEntity entry) {
    return {
      'planDate': entry.planDate,
      'dayMealId': entry.dayMealId,
      'foodId': entry.foodId,
      'quantity': entry.quantity,
      'unit': entry.unit.isEmpty ? 'g' : entry.unit,
    };
  }
}
