import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
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
}
