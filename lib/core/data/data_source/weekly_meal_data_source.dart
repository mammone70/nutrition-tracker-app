import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/weekly_meal_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class WeeklyMealDataSource {
  final log = Logger('WeeklyMealDataSource');
  final HiveDBProvider _db;

  WeeklyMealDataSource(this._db);

  Box<WeeklyMealDBO> get _box => _db.weeklyMealBox;

  Future<void> upsert(WeeklyMealDBO entry) async {
    log.fine(
      'Upserting weekly meal day=${entry.dayOfWeek} index=${entry.mealIndex}',
    );
    await _box.put(entry.id, entry);
  }

  Future<void> upsertAll(List<WeeklyMealDBO> entries) async {
    log.fine('Upserting ${entries.length} weekly meals');
    await _box.putAll({for (final e in entries) e.id: e});
  }

  Future<List<WeeklyMealDBO>> getAll() async => _box.values.toList();

  Future<WeeklyMealDBO?> getById(String id) async => _box.get(id);

  Future<List<WeeklyMealDBO>> getByDayOfWeek(int dayOfWeek) async {
    final list =
        _box.values.where((e) => e.dayOfWeek == dayOfWeek).toList()
          ..sort((a, b) => a.mealIndex.compareTo(b.mealIndex));
    return list;
  }

  Future<WeeklyMealDBO?> getByDayAndIndex(int dayOfWeek, int mealIndex) async {
    try {
      return _box.values.firstWhere(
        (e) => e.dayOfWeek == dayOfWeek && e.mealIndex == mealIndex,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteById(String id) async {
    log.fine('Deleting weekly meal $id');
    await _box.delete(id);
  }

  Future<void> deleteForDay(int dayOfWeek) async {
    final ids =
        _box.values.where((e) => e.dayOfWeek == dayOfWeek).map((e) => e.id);
    for (final id in ids) {
      await _box.delete(id);
    }
  }
}
