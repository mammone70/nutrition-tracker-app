import 'package:opennutritracker/core/data/data_source/weekly_meal_plan_entry_data_source.dart';
import 'package:opennutritracker/core/data/dbo/weekly_meal_plan_entry_dbo.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_plan_entry_entity.dart';

class WeeklyMealPlanEntryRepository {
  final WeeklyMealPlanEntryDataSource _dataSource;

  WeeklyMealPlanEntryRepository(this._dataSource);

  Future<void> upsert(WeeklyMealPlanEntryEntity entity) async {
    await _dataSource.upsert(WeeklyMealPlanEntryDBO.fromEntity(entity));
  }

  Future<void> upsertAll(List<WeeklyMealPlanEntryEntity> entities) async {
    await _dataSource.upsertAll(
      entities.map(WeeklyMealPlanEntryDBO.fromEntity).toList(),
    );
  }

  Future<List<WeeklyMealPlanEntryEntity>> getAll() async {
    final dbos = await _dataSource.getAll();
    return dbos.map(WeeklyMealPlanEntryEntity.fromDBO).toList();
  }

  Future<WeeklyMealPlanEntryEntity?> getById(String id) async {
    final dbo = await _dataSource.getById(id);
    return dbo == null ? null : WeeklyMealPlanEntryEntity.fromDBO(dbo);
  }

  Future<List<WeeklyMealPlanEntryEntity>> getByWeeklyMealId(
    String weeklyMealId,
  ) async {
    final dbos = await _dataSource.getByWeeklyMealId(weeklyMealId);
    return dbos.map(WeeklyMealPlanEntryEntity.fromDBO).toList();
  }

  Future<List<WeeklyMealPlanEntryEntity>> getByWeeklyMealIds(
    Set<String> weeklyMealIds,
  ) async {
    final dbos = await _dataSource.getByWeeklyMealIds(weeklyMealIds);
    return dbos.map(WeeklyMealPlanEntryEntity.fromDBO).toList();
  }

  Future<void> deleteById(String id) async {
    await _dataSource.deleteById(id);
  }

  Future<void> deleteByWeeklyMealId(String weeklyMealId) async {
    await _dataSource.deleteByWeeklyMealId(weeklyMealId);
  }
}
