import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/meal_plan_entry_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class MealPlanEntryDataSource {
  final log = Logger('MealPlanEntryDataSource');
  final HiveDBProvider _db;

  MealPlanEntryDataSource(this._db);

  Box<MealPlanEntryDBO> get _box => _db.mealPlanEntryBox;

  Future<void> upsert(MealPlanEntryDBO entry) async {
    log.fine('Upserting meal plan entry ${entry.id}');
    await _box.put(entry.id, entry);
  }

  Future<void> upsertAll(List<MealPlanEntryDBO> entries) async {
    log.fine('Upserting ${entries.length} meal plan entries');
    await _box.putAll({for (final e in entries) e.id: e});
  }

  Future<List<MealPlanEntryDBO>> getAll() async => _box.values.toList();

  Future<MealPlanEntryDBO?> getById(String id) async => _box.get(id);

  Future<List<MealPlanEntryDBO>> getByPlanDate(String planDate) async {
    return _box.values.where((e) => e.planDate == planDate).toList();
  }

  Future<List<MealPlanEntryDBO>> getByDayMealId(String dayMealId) async {
    return _box.values.where((e) => e.dayMealId == dayMealId).toList();
  }

  Future<void> deleteById(String id) async {
    log.fine('Deleting meal plan entry $id');
    await _box.delete(id);
  }

  Future<void> deleteForDate(String planDate) async {
    final ids =
        _box.values.where((e) => e.planDate == planDate).map((e) => e.id);
    for (final id in ids) {
      await _box.delete(id);
    }
  }

  Future<void> deleteByDayMealId(String dayMealId) async {
    final ids =
        _box.values.where((e) => e.dayMealId == dayMealId).map((e) => e.id);
    for (final id in ids) {
      await _box.delete(id);
    }
  }
}
