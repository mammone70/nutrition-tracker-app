import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/weekly_meal_plan_entry_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class WeeklyMealPlanEntryDataSource {
  final log = Logger('WeeklyMealPlanEntryDataSource');
  final HiveDBProvider _db;

  WeeklyMealPlanEntryDataSource(this._db);

  Box<WeeklyMealPlanEntryDBO> get _box => _db.weeklyMealPlanEntryBox;

  Future<void> upsert(WeeklyMealPlanEntryDBO entry) async {
    log.fine('Upserting weekly meal plan entry ${entry.id}');
    await _box.put(entry.id, entry);
  }

  Future<void> upsertAll(List<WeeklyMealPlanEntryDBO> entries) async {
    log.fine('Upserting ${entries.length} weekly meal plan entries');
    await _box.putAll({for (final e in entries) e.id: e});
  }

  Future<List<WeeklyMealPlanEntryDBO>> getAll() async => _box.values.toList();

  Future<WeeklyMealPlanEntryDBO?> getById(String id) async => _box.get(id);

  Future<List<WeeklyMealPlanEntryDBO>> getByWeeklyMealId(
    String weeklyMealId,
  ) async {
    return _box.values.where((e) => e.weeklyMealId == weeklyMealId).toList();
  }

  Future<List<WeeklyMealPlanEntryDBO>> getByWeeklyMealIds(
    Set<String> weeklyMealIds,
  ) async {
    return _box.values
        .where((e) => weeklyMealIds.contains(e.weeklyMealId))
        .toList();
  }

  Future<void> deleteById(String id) async {
    log.fine('Deleting weekly meal plan entry $id');
    await _box.delete(id);
  }

  Future<void> deleteByWeeklyMealId(String weeklyMealId) async {
    final ids = _box.values
        .where((e) => e.weeklyMealId == weeklyMealId)
        .map((e) => e.id)
        .toList();
    for (final id in ids) {
      await _box.delete(id);
    }
  }
}
