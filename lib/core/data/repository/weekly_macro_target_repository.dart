import 'package:opennutritracker/core/data/data_source/weekly_macro_target_data_source.dart';
import 'package:opennutritracker/core/data/dbo/weekly_macro_target_dbo.dart';
import 'package:opennutritracker/core/domain/entity/weekly_macro_target_entity.dart';

class WeeklyMacroTargetRepository {
  final WeeklyMacroTargetDataSource _dataSource;

  WeeklyMacroTargetRepository(this._dataSource);

  Future<void> upsert(WeeklyMacroTargetEntity entity) async {
    await _dataSource.upsert(WeeklyMacroTargetDBO.fromEntity(entity));
  }

  Future<List<WeeklyMacroTargetEntity>> getAll() async {
    final dbos = await _dataSource.getAll();
    return dbos.map(WeeklyMacroTargetEntity.fromDBO).toList();
  }

  Future<WeeklyMacroTargetEntity?> getById(String id) async {
    final dbo = await _dataSource.getById(id);
    return dbo == null ? null : WeeklyMacroTargetEntity.fromDBO(dbo);
  }

  Future<WeeklyMacroTargetEntity?> getByDayOfWeek(int dayOfWeek) async {
    final dbo = await _dataSource.getByDayOfWeek(dayOfWeek);
    return dbo == null ? null : WeeklyMacroTargetEntity.fromDBO(dbo);
  }

  Future<void> deleteById(String id) async {
    await _dataSource.deleteById(id);
  }
}
