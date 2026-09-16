import 'package:opennutritracker/core/data/repository/day_meal_repository.dart';
import 'package:opennutritracker/core/data/repository/meal_plan_entry_repository.dart';
import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class GetDayMealsUsecase {
  final DayMealRepository _mealRepository;
  final MealPlanEntryRepository _entryRepository;

  GetDayMealsUsecase(this._mealRepository, this._entryRepository);

  Future<List<DayMealEntity>> getMeals(String planDate) =>
      _mealRepository.getByPlanDate(planDate);

  Future<List<MealPlanEntryEntity>> getEntries(String planDate) =>
      _entryRepository.getByPlanDate(planDate);
}

class SaveDayMealsUsecase {
  final DayMealRepository _mealRepository;
  final MealPlanEntryRepository _entryRepository;
  final SyncService _syncService;

  SaveDayMealsUsecase(
    this._mealRepository,
    this._entryRepository,
    this._syncService,
  );

  Future<void> saveDay({
    required String planDate,
    required List<DayMealEntity> meals,
    required List<MealPlanEntryEntity> entries,
  }) async {
    final existingMeals = await _mealRepository.getByPlanDate(planDate);
    final existingEntries = await _entryRepository.getByPlanDate(planDate);
    final keepMealIds = meals.map((m) => m.id).toSet();
    final keepEntryIds = entries.map((e) => e.id).toSet();

    for (final old in existingEntries) {
      if (!keepEntryIds.contains(old.id)) {
        await _entryRepository.deleteById(old.id);
        await _syncService.enqueueMealPlanEntryDelete(old.id);
      }
    }
    for (final old in existingMeals) {
      if (!keepMealIds.contains(old.id)) {
        await _mealRepository.deleteById(old.id);
        await _syncService.enqueueDayMealDelete(old.id);
      }
    }

    for (final meal in meals) {
      await _mealRepository.upsert(meal);
      await _syncService.enqueueDayMealUpsert(meal);
    }
    for (final entry in entries) {
      await _entryRepository.upsert(entry);
      await _syncService.enqueueMealPlanEntryUpsert(entry);
    }
  }
}
