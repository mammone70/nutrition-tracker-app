import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/day_meal_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class DayMealDataSource {
  final log = Logger('DayMealDataSource');
  final HiveDBProvider _db;

  DayMealDataSource(this._db);

  Box<DayMealDBO> get _box => _db.dayMealBox;

  Future<void> upsert(DayMealDBO entry) async {
    log.fine(
      'Upserting day meal date=${entry.planDate} index=${entry.mealIndex}',
    );
    await _box.put(entry.id, entry);
  }

  Future<void> upsertAll(List<DayMealDBO> entries) async {
    log.fine('Upserting ${entries.length} day meals');
    await _box.putAll({for (final e in entries) e.id: e});
  }

  Future<List<DayMealDBO>> getAll() async => _box.values.toList();

  Future<DayMealDBO?> getById(String id) async => _box.get(id);

  Future<List<DayMealDBO>> getByPlanDate(String planDate) async {
    final list = _box.values.where((e) => e.planDate == planDate).toList()
      ..sort((a, b) => a.mealIndex.compareTo(b.mealIndex));
    return list;
  }

  Future<DayMealDBO?> getByDateAndIndex(String planDate, int mealIndex) async {
    try {
      return _box.values.firstWhere(
        (e) => e.planDate == planDate && e.mealIndex == mealIndex,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteById(String id) async {
    log.fine('Deleting day meal $id');
    await _box.delete(id);
  }

  Future<void> deleteForDate(String planDate) async {
    final ids =
        _box.values.where((e) => e.planDate == planDate).map((e) => e.id);
    for (final id in ids) {
      await _box.delete(id);
    }
  }
}
