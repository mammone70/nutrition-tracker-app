import 'package:opennutritracker/core/data/data_source/confirmed_plan_food_data_source.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
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
  if (lower.contains('snack')) {
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

/// Copies scheduled meal-plan foods into today's diary as logged intakes,
/// and remembers the plan-entry → intake link for confirm/unconfirm UI.
class ConfirmMealPlanToDiaryUsecase {
  final AddIntakeUsecase _addIntake;
  final AddTrackedDayUsecase _addTrackedDay;
  final ConfirmedPlanFoodDataSource _confirmedLinks;

  ConfirmMealPlanToDiaryUsecase(
    this._addIntake,
    this._addTrackedDay,
    this._confirmedLinks,
  );

  Map<String, String> confirmedIntakeIdsForDate(DateTime day) {
    return _confirmedLinks.intakeIdsForDate(day.toParsedDay());
  }

  Future<int> confirmFood({
    required MealPlanFoodEntry food,
    required EffectiveMealBlock meal,
    required DateTime day,
    required double calorieGoal,
    required double carbsGoal,
    required double fatGoal,
    required double proteinGoal,
  }) async {
    final planDate = day.toParsedDay();
    final existing = _confirmedLinks.getLink(
      planDate: planDate,
      entryId: food.id,
    );
    if (existing != null) return 0;

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
      count += await confirmFood(
        food: food,
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
    final intakeId = IdGenerator.getUniqueID();

    // Prefer planned meal time when present (HH:MM); else noon.
    var hour = 12;
    var minute = 0;
    final mealTime = meal.mealTime?.trim();
    if (mealTime != null && mealTime.contains(':')) {
      final parts = mealTime.split(':');
      hour = int.tryParse(parts[0]) ?? 12;
      minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    }

    final intake = IntakeEntity(
      id: intakeId,
      unit: unit,
      amount: amount,
      type: type,
      meal: mealEntity,
      dateTime: DateTime(day.year, day.month, day.day, hour, minute),
    );

    await _addIntake.addIntake(intake);
    await _confirmedLinks.putLink(
      planDate: day.toParsedDay(),
      entryId: food.id,
      intakeId: intakeId,
    );

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

/// Removes a confirmed plan food from the diary and clears the confirm link.
class UnconfirmMealPlanFoodUsecase {
  final DeleteIntakeUsecase _deleteIntake;
  final GetIntakeUsecase _getIntake;
  final AddTrackedDayUsecase _addTrackedDay;
  final ConfirmedPlanFoodDataSource _confirmedLinks;

  UnconfirmMealPlanFoodUsecase(
    this._deleteIntake,
    this._getIntake,
    this._addTrackedDay,
    this._confirmedLinks,
  );

  Future<bool> unconfirmFood({
    required String entryId,
    required DateTime day,
  }) async {
    final planDate = day.toParsedDay();
    final link = _confirmedLinks.getLink(planDate: planDate, entryId: entryId);
    if (link == null) return false;

    final intake = await _getIntake.getIntakeById(link.intakeId);
    if (intake != null) {
      await _deleteIntake.deleteIntake(intake);
      await _addTrackedDay.removeDayCaloriesTracked(day, intake.totalKcal);
      await _addTrackedDay.removeDayMacrosTracked(
        day,
        carbsTracked: intake.totalCarbsGram,
        fatTracked: intake.totalFatsGram,
        proteinTracked: intake.totalProteinsGram,
      );
    }
    await _confirmedLinks.removeLink(planDate: planDate, entryId: entryId);
    return true;
  }

  Future<int> unconfirmMeal({
    required EffectiveMealBlock meal,
    required DateTime day,
  }) async {
    var count = 0;
    for (final food in meal.entries) {
      if (await unconfirmFood(entryId: food.id, day: day)) count++;
    }
    return count;
  }
}
