import 'package:opennutritracker/core/data/repository/day_meal_repository.dart';
import 'package:opennutritracker/core/data/repository/meal_plan_entry_repository.dart';
import 'package:opennutritracker/core/data/repository/weekly_meal_plan_entry_repository.dart';
import 'package:opennutritracker/core/data/repository/weekly_meal_repository.dart';
import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/meal_plan_utils.dart';
import 'package:uuid/uuid.dart';

class MaterializeWeeklyToDayUsecase {
  static const _uuid = Uuid();

  final DayMealRepository _dayMealRepository;
  final MealPlanEntryRepository _mealPlanEntryRepository;
  final WeeklyMealRepository _weeklyMealRepository;
  final WeeklyMealPlanEntryRepository _weeklyMealPlanEntryRepository;
  final SyncService _syncService;

  MaterializeWeeklyToDayUsecase(
    this._dayMealRepository,
    this._mealPlanEntryRepository,
    this._weeklyMealRepository,
    this._weeklyMealPlanEntryRepository,
    this._syncService,
  );

  /// Copies the weekly template for [planDate]'s weekday into day overrides.
  /// No-op if day meals/entries already exist.
  Future<void> execute(String planDate) async {
    final existingMeals = await _dayMealRepository.getByPlanDate(planDate);
    final existingEntries =
        await _mealPlanEntryRepository.getByPlanDate(planDate);
    if (existingMeals.isNotEmpty || existingEntries.isNotEmpty) {
      return;
    }

    final dayOfWeek = dayOfWeekFromDateString(planDate);
    final weeklyMeals =
        await _weeklyMealRepository.getByDayOfWeek(dayOfWeek);
    final weeklyEntries = await _weeklyMealPlanEntryRepository
        .getByWeeklyMealIds(weeklyMeals.map((m) => m.id).toSet());

    final mealIdMap = <String, String>{};
    final now = DateTime.now().toUtc();
    for (final meal in weeklyMeals) {
      final dayMeal = DayMealEntity(
        id: _uuid.v4(),
        planDate: planDate,
        mealIndex: meal.mealIndex,
        name: meal.name,
        mealTime: meal.mealTime,
        updatedAt: now,
      );
      mealIdMap[meal.id] = dayMeal.id;
      await _dayMealRepository.upsert(dayMeal);
      await _syncService.enqueueDayMealUpsert(dayMeal);
    }

    for (final entry in weeklyEntries) {
      final dayMealId = mealIdMap[entry.weeklyMealId];
      if (dayMealId == null) continue;
      final dayEntry = MealPlanEntryEntity(
        id: _uuid.v4(),
        planDate: planDate,
        dayMealId: dayMealId,
        foodId: entry.foodId,
        foodName: entry.foodName,
        brand: entry.brand,
        caloriesPer100: entry.caloriesPer100,
        proteinPer100: entry.proteinPer100,
        fatPer100: entry.fatPer100,
        carbsPer100: entry.carbsPer100,
        quantity: entry.quantity,
        unit: entry.unit,
        updatedAt: now,
      );
      await _mealPlanEntryRepository.upsert(dayEntry);
      await _syncService.enqueueMealPlanEntryUpsert(dayEntry);
    }
  }
}

class ResetDayToWeeklyUsecase {
  final DayMealRepository _dayMealRepository;
  final MealPlanEntryRepository _mealPlanEntryRepository;
  final SyncService _syncService;

  ResetDayToWeeklyUsecase(
    this._dayMealRepository,
    this._mealPlanEntryRepository,
    this._syncService,
  );

  Future<void> execute(String planDate) async {
    final entries = await _mealPlanEntryRepository.getByPlanDate(planDate);
    for (final entry in entries) {
      await _mealPlanEntryRepository.deleteById(entry.id);
      await _syncService.enqueueMealPlanEntryDelete(entry.id);
    }
    final meals = await _dayMealRepository.getByPlanDate(planDate);
    for (final meal in meals) {
      await _dayMealRepository.deleteById(meal.id);
      await _syncService.enqueueDayMealDelete(meal.id);
    }
  }
}
