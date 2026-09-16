import 'package:opennutritracker/core/data/data_source/meal_plan_entry_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_plan_entry_dbo.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';

class MealPlanEntryRepository {
  final MealPlanEntryDataSource _dataSource;

  MealPlanEntryRepository(this._dataSource);

  Future<void> upsert(MealPlanEntryEntity entity) async {
    await _dataSource.upsert(MealPlanEntryDBO.fromEntity(entity));
  }

  Future<void> upsertAll(List<MealPlanEntryEntity> entities) async {
    await _dataSource.upsertAll(
      entities.map(MealPlanEntryDBO.fromEntity).toList(),
    );
  }

  Future<List<MealPlanEntryEntity>> getAll() async {
    final dbos = await _dataSource.getAll();
    return dbos.map(MealPlanEntryEntity.fromDBO).toList();
  }

  Future<MealPlanEntryEntity?> getById(String id) async {
    final dbo = await _dataSource.getById(id);
    return dbo == null ? null : MealPlanEntryEntity.fromDBO(dbo);
  }

  Future<List<MealPlanEntryEntity>> getByPlanDate(String planDate) async {
    final dbos = await _dataSource.getByPlanDate(planDate);
    return dbos.map(MealPlanEntryEntity.fromDBO).toList();
  }

  Future<void> deleteById(String id) async {
    await _dataSource.deleteById(id);
  }

  Future<void> deleteForDate(String planDate) async {
    await _dataSource.deleteForDate(planDate);
  }

  Future<void> deleteByDayMealId(String dayMealId) async {
    await _dataSource.deleteByDayMealId(dayMealId);
  }
}
