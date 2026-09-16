import 'package:opennutritracker/core/data/data_source/day_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/day_meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';

class DayMealRepository {
  final DayMealDataSource _dataSource;

  DayMealRepository(this._dataSource);

  Future<void> upsert(DayMealEntity entity) async {
    await _dataSource.upsert(DayMealDBO.fromEntity(entity));
  }

  Future<void> upsertAll(List<DayMealEntity> entities) async {
    await _dataSource.upsertAll(entities.map(DayMealDBO.fromEntity).toList());
  }

  Future<List<DayMealEntity>> getAll() async {
    final dbos = await _dataSource.getAll();
    return dbos.map(DayMealEntity.fromDBO).toList();
  }

  Future<DayMealEntity?> getById(String id) async {
    final dbo = await _dataSource.getById(id);
    return dbo == null ? null : DayMealEntity.fromDBO(dbo);
  }

  Future<List<DayMealEntity>> getByPlanDate(String planDate) async {
    final dbos = await _dataSource.getByPlanDate(planDate);
    return dbos.map(DayMealEntity.fromDBO).toList();
  }

  Future<void> deleteById(String id) async {
    await _dataSource.deleteById(id);
  }

  Future<void> deleteForDate(String planDate) async {
    await _dataSource.deleteForDate(planDate);
  }
}
