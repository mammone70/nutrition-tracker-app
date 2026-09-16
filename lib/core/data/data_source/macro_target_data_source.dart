import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/macro_target_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class MacroTargetDataSource {
  final log = Logger('MacroTargetDataSource');
  final HiveDBProvider _db;

  MacroTargetDataSource(this._db);

  Box<MacroTargetDBO> get _box => _db.macroTargetBox;

  Future<void> upsert(MacroTargetDBO entry) async {
    log.fine('Upserting macro target date=${entry.targetDate}');
    final existing = _box.values
        .where((e) => e.targetDate == entry.targetDate && e.id != entry.id)
        .toList();
    for (final old in existing) {
      await _box.delete(old.id);
    }
    await _box.put(entry.id, entry);
  }

  Future<List<MacroTargetDBO>> getAll() async => _box.values.toList();

  Future<MacroTargetDBO?> getById(String id) async => _box.get(id);

  Future<MacroTargetDBO?> getByTargetDate(String targetDate) async {
    try {
      return _box.values.firstWhere((e) => e.targetDate == targetDate);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteById(String id) async {
    log.fine('Deleting macro target $id');
    await _box.delete(id);
  }
}
