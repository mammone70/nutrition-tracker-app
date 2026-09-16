import 'package:opennutritracker/core/data/data_source/macro_target_data_source.dart';
import 'package:opennutritracker/core/data/dbo/macro_target_dbo.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';

class MacroTargetRepository {
  final MacroTargetDataSource _dataSource;

  MacroTargetRepository(this._dataSource);

  Future<void> upsert(MacroTargetEntity entity) async {
    await _dataSource.upsert(MacroTargetDBO.fromEntity(entity));
  }

  Future<List<MacroTargetEntity>> getAll() async {
    final dbos = await _dataSource.getAll();
    return dbos.map(MacroTargetEntity.fromDBO).toList();
  }

  Future<MacroTargetEntity?> getById(String id) async {
    final dbo = await _dataSource.getById(id);
    return dbo == null ? null : MacroTargetEntity.fromDBO(dbo);
  }

  Future<MacroTargetEntity?> getByTargetDate(String targetDate) async {
    final dbo = await _dataSource.getByTargetDate(targetDate);
    return dbo == null ? null : MacroTargetEntity.fromDBO(dbo);
  }

  Future<void> deleteById(String id) async {
    await _dataSource.deleteById(id);
  }
}
