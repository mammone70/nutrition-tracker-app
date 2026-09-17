import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

/// Maps a meal-plan slot onto the diary's four meal types.
IntakeTypeEntity intakeTypeForMealPlan({
  required int mealIndex,
  required String name,
}) {
  final lower = name.trim().toLowerCase();
  if (lower.contains('breakfast') || lower.contains('frühstück')) {
    return IntakeTypeEntity.breakfast;
  }
  if (lower.contains('lunch') || lower.contains('mittag')) {
    return IntakeTypeEntity.lunch;
  }
  if (lower.contains('dinner') ||
      lower.contains('supper') ||
      lower.contains('abend')) {
    return IntakeTypeEntity.dinner;
  }
  if (lower.contains('snack') || lower.contains('snack')) {
    return IntakeTypeEntity.snack;
  }
  return switch (mealIndex) {
    0 => IntakeTypeEntity.breakfast,
    1 => IntakeTypeEntity.lunch,
    2 => IntakeTypeEntity.dinner,
    _ => IntakeTypeEntity.snack,
  };
}

MealEntity mealEntityFromPlanFood(MealPlanFoodEntry food) {
  return MealEntity(
    code: food.foodId.isNotEmpty ? food.foodId : IdGenerator.getUniqueID(),
    name: food.foodName,
    brands: food.brand,
    url: null,
    mealQuantity: null,
    mealUnit: food.unit,
    servingQuantity: null,
    servingUnit: null,
    servingSize: null,
    nutriments: MealNutrimentsEntity(
      energyKcal100: food.caloriesPer100,
      carbohydrates100: food.carbsPer100,
      fat100: food.fatPer100,
      proteins100: food.proteinPer100,
      sugars100: null,
      saturatedFat100: null,
      fiber100: null,
    ),
    source: MealSourceEntity.custom,
  );
}

/// Copies scheduled meal-plan foods into today's diary as logged intakes.
class ConfirmMealPlanToDiaryUsecase {
  final AddIntakeUsecase _addIntake;
  final AddTrackedDayUsecase _addTrackedDay;

  ConfirmMealPlanToDiaryUsecase(this._addIntake, this._addTrackedDay);

  Future<int> confirmFood({
    required MealPlanFoodEntry food,
    required EffectiveMealBlock meal,
    required DateTime day,
    required double calorieGoal,
    required double carbsGoal,
    required double fatGoal,
    required double proteinGoal,
  }) async {
    await _logFood(
      food: food,
      meal: meal,
      day: day,
      calorieGoal: calorieGoal,
      carbsGoal: carbsGoal,
      fatGoal: fatGoal,
      proteinGoal: proteinGoal,
    );
    return 1;
  }

  Future<int> confirmMeal({
    required EffectiveMealBlock meal,
    required DateTime day,
    required double calorieGoal,
    required double carbsGoal,
    required double fatGoal,
    required double proteinGoal,
  }) async {
    var count = 0;
    for (final food in meal.entries) {
      await _logFood(
        food: food,
        meal: meal,
        day: day,
        calorieGoal: calorieGoal,
        carbsGoal: carbsGoal,
        fatGoal: fatGoal,
        proteinGoal: proteinGoal,
      );
      count++;
    }
    return count;
  }

  Future<int> confirmPlan({
    required EffectiveMealPlan plan,
    required DateTime day,
    required double calorieGoal,
    required double carbsGoal,
    required double fatGoal,
    required double proteinGoal,
  }) async {
    var count = 0;
    for (final meal in plan.meals) {
      count += await confirmMeal(
        meal: meal,
        day: day,
        calorieGoal: calorieGoal,
        carbsGoal: carbsGoal,
        fatGoal: fatGoal,
        proteinGoal: proteinGoal,
      );
    }
    return count;
  }

  Future<void> _logFood({
    required MealPlanFoodEntry food,
    required EffectiveMealBlock meal,
    required DateTime day,
    required double calorieGoal,
    required double carbsGoal,
    required double fatGoal,
    required double proteinGoal,
  }) async {
    final mealEntity = mealEntityFromPlanFood(food);
    final type = intakeTypeForMealPlan(
      mealIndex: meal.mealIndex,
      name: meal.name,
    );
    final amount = food.quantity;
    final unit = food.unit.isEmpty ? 'g' : food.unit;

    final intake = IntakeEntity(
      id: IdGenerator.getUniqueID(),
      unit: unit,
      amount: amount,
      type: type,
      meal: mealEntity,
      dateTime: DateTime(day.year, day.month, day.day, 12),
    );

    await _addIntake.addIntake(intake);

    final hasDay = await _addTrackedDay.hasTrackedDay(day);
    if (!hasDay) {
      await _addTrackedDay.addNewTrackedDay(
        day,
        calorieGoal,
        carbsGoal,
        fatGoal,
        proteinGoal,
      );
    }
    await _addTrackedDay.addDayCaloriesTracked(day, intake.totalKcal);
    await _addTrackedDay.addDayMacrosTracked(
      day,
      carbsTracked: intake.totalCarbsGram,
      fatTracked: intake.totalFatsGram,
      proteinTracked: intake.totalProteinsGram,
    );
  }
}
