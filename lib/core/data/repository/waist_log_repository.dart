import 'package:opennutritracker/core/data/data_source/waist_log_data_source.dart';
import 'package:opennutritracker/core/data/dbo/waist_log_dbo.dart';
import 'package:opennutritracker/core/domain/entity/waist_log_entity.dart';

class WaistLogRepository {
  final WaistLogDataSource _dataSource;

  WaistLogRepository(this._dataSource);

  Future<void> addEntry(WaistLogEntity entry) async {
    await _dataSource.addEntry(WaistLogDBO.fromWaistLogEntity(entry));
  }

  Future<List<WaistLogEntity>> getAllEntries() async {
    final dbos = await _dataSource.allEntries();
    return dbos.map(WaistLogEntity.fromWaistLogDBO).toList();
  }

  Future<List<WaistLogEntity>> getEntriesInRange(
    DateTime from,
    DateTime to,
  ) async {
    final dbos = await _dataSource.entriesInRange(from, to);
    return dbos.map(WaistLogEntity.fromWaistLogDBO).toList();
  }

  Future<WaistLogEntity?> getEntry(DateTime date) async {
    final dbo = await _dataSource.getEntry(date);
    return dbo == null ? null : WaistLogEntity.fromWaistLogDBO(dbo);
  }

  Future<void> deleteEntry(DateTime date) async {
    await _dataSource.deleteEntry(date);
  }
}
