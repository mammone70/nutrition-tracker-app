import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/waist_log_dbo.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class WaistLogDataSource {
  final log = Logger('WaistLogDataSource');
  final HiveDBProvider _db;

  WaistLogDataSource(this._db);

  Box<WaistLogDBO> get _box => _db.waistLogBox;

  Future<void> addEntry(WaistLogDBO entry) async {
    log.fine('Adding waist log entry for ${entry.date}');
    await _box.put(entry.date.toParsedDay(), entry);
  }

  Future<List<WaistLogDBO>> allEntries() async => _box.values.toList();

  Future<List<WaistLogDBO>> entriesInRange(DateTime from, DateTime to) async {
    return _box.values
        .where(
          (entry) => !entry.date.isBefore(from) && !entry.date.isAfter(to),
        )
        .toList();
  }

  Future<WaistLogDBO?> getEntry(DateTime date) async {
    return _box.get(date.toParsedDay());
  }

  Future<void> deleteEntry(DateTime date) async {
    log.fine('Deleting waist log entry for $date');
    await _box.delete(date.toParsedDay());
  }
}
