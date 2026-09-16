import 'package:opennutritracker/core/data/data_source/weekly_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/weekly_meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_entity.dart';

class WeeklyMealRepository {
  final WeeklyMealDataSource _dataSource;

  WeeklyMealRepository(this._dataSource);

  Future<void> upsert(WeeklyMealEntity entity) async {
    await _dataSource.upsert(WeeklyMealDBO.fromEntity(entity));
  }

  Future<void> upsertAll(List<WeeklyMealEntity> entities) async {
    await _dataSource.upsertAll(
      entities.map(WeeklyMealDBO.fromEntity).toList(),
    );
  }

  Future<List<WeeklyMealEntity>> getAll() async {
    final dbos = await _dataSource.getAll();
    return dbos.map(WeeklyMealEntity.fromDBO).toList();
  }

  Future<WeeklyMealEntity?> getById(String id) async {
    final dbo = await _dataSource.getById(id);
    return dbo == null ? null : WeeklyMealEntity.fromDBO(dbo);
  }

  Future<List<WeeklyMealEntity>> getByDayOfWeek(int dayOfWeek) async {
    final dbos = await _dataSource.getByDayOfWeek(dayOfWeek);
    return dbos.map(WeeklyMealEntity.fromDBO).toList();
  }

  Future<void> deleteById(String id) async {
    await _dataSource.deleteById(id);
  }

  Future<void> deleteForDay(int dayOfWeek) async {
    await _dataSource.deleteForDay(dayOfWeek);
  }
}
