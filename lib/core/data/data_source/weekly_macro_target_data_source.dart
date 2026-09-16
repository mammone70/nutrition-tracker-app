import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/weekly_macro_target_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class WeeklyMacroTargetDataSource {
  final log = Logger('WeeklyMacroTargetDataSource');
  final HiveDBProvider _db;

  WeeklyMacroTargetDataSource(this._db);

  Box<WeeklyMacroTargetDBO> get _box => _db.weeklyMacroTargetBox;

  Future<void> upsert(WeeklyMacroTargetDBO entry) async {
    log.fine('Upserting weekly macro target day=${entry.dayOfWeek}');
    // One row per weekday: replace any existing dayOfWeek match.
    final existing = _box.values
        .where((e) => e.dayOfWeek == entry.dayOfWeek && e.id != entry.id)
        .toList();
    for (final old in existing) {
      await _box.delete(old.id);
    }
    await _box.put(entry.id, entry);
  }

  Future<List<WeeklyMacroTargetDBO>> getAll() async => _box.values.toList();

  Future<WeeklyMacroTargetDBO?> getById(String id) async => _box.get(id);

  Future<WeeklyMacroTargetDBO?> getByDayOfWeek(int dayOfWeek) async {
    try {
      return _box.values.firstWhere((e) => e.dayOfWeek == dayOfWeek);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteById(String id) async {
    log.fine('Deleting weekly macro target $id');
    await _box.delete(id);
  }
}
