import 'package:opennutritracker/core/data/repository/weekly_meal_plan_entry_repository.dart';
import 'package:opennutritracker/core/data/repository/weekly_meal_repository.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class GetWeeklyMealsUsecase {
  final WeeklyMealRepository _mealRepository;
  final WeeklyMealPlanEntryRepository _entryRepository;

  GetWeeklyMealsUsecase(this._mealRepository, this._entryRepository);

  Future<List<WeeklyMealEntity>> getMealsByDay(int dayOfWeek) =>
      _mealRepository.getByDayOfWeek(dayOfWeek);

  Future<List<WeeklyMealPlanEntryEntity>> getEntriesForMeals(
    List<WeeklyMealEntity> meals,
  ) {
    return _entryRepository.getByWeeklyMealIds(meals.map((m) => m.id).toSet());
  }

  Future<List<WeeklyMealEntity>> getAllMeals() => _mealRepository.getAll();

  Future<List<WeeklyMealPlanEntryEntity>> getAllEntries() =>
      _entryRepository.getAll();
}

class SaveWeeklyMealsUsecase {
  final WeeklyMealRepository _mealRepository;
  final WeeklyMealPlanEntryRepository _entryRepository;
  final SyncService _syncService;

  SaveWeeklyMealsUsecase(
    this._mealRepository,
    this._entryRepository,
    this._syncService,
  );

  /// Replaces the template for [dayOfWeek] with [meals] + [entries].
  Future<void> saveDay({
    required int dayOfWeek,
    required List<WeeklyMealEntity> meals,
    required List<WeeklyMealPlanEntryEntity> entries,
  }) async {
    final existingMeals = await _mealRepository.getByDayOfWeek(dayOfWeek);
    final existingMealIds = existingMeals.map((m) => m.id).toSet();
    final keepMealIds = meals.map((m) => m.id).toSet();

    for (final old in existingMeals) {
      if (!keepMealIds.contains(old.id)) {
        final oldEntries =
            await _entryRepository.getByWeeklyMealId(old.id);
        for (final entry in oldEntries) {
          await _entryRepository.deleteById(entry.id);
          await _syncService.enqueueWeeklyMealPlanEntryDelete(entry.id);
        }
        await _mealRepository.deleteById(old.id);
        await _syncService.enqueueWeeklyMealDelete(old.id);
      }
    }

    for (final meal in meals) {
      await _mealRepository.upsert(meal);
      await _syncService.enqueueWeeklyMealUpsert(meal);
    }

    final keepEntryIds = entries.map((e) => e.id).toSet();
    if (existingMealIds.isNotEmpty) {
      final existingEntries =
          await _entryRepository.getByWeeklyMealIds(existingMealIds);
      for (final old in existingEntries) {
        if (!keepEntryIds.contains(old.id)) {
          await _entryRepository.deleteById(old.id);
          await _syncService.enqueueWeeklyMealPlanEntryDelete(old.id);
        }
      }
    }

    for (final entry in entries) {
      await _entryRepository.upsert(entry);
      await _syncService.enqueueWeeklyMealPlanEntryUpsert(entry);
    }
  }
}
