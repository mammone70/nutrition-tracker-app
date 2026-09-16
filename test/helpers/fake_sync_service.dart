import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

/// No-op [SyncService] for unit tests that construct write use cases.
class FakeSyncService extends Fake implements SyncService {
  @override
  Future<void> enqueueIntakeUpsert(IntakeEntity intake) async {}

  @override
  Future<void> enqueueIntakeDelete(String intakeId) async {}

  @override
  Future<void> enqueueWeightLogUpsert(WeightLogEntity entry) async {}

  @override
  Future<void> enqueueWeightLogDelete(DateTime date) async {}

  @override
  Future<void> enqueueWeeklyMacroTargetUpsert(
    WeeklyMacroTargetEntity target,
  ) async {}

  @override
  Future<void> enqueueWeeklyMacroTargetDelete(String id) async {}

  @override
  Future<void> enqueueMacroTargetUpsert(MacroTargetEntity target) async {}

  @override
  Future<void> enqueueMacroTargetDelete(String id) async {}

  @override
  Future<void> enqueueWeeklyMealUpsert(WeeklyMealEntity meal) async {}

  @override
  Future<void> enqueueWeeklyMealDelete(String id) async {}

  @override
  Future<void> enqueueWeeklyMealPlanEntryUpsert(
    WeeklyMealPlanEntryEntity entry,
  ) async {}

  @override
  Future<void> enqueueWeeklyMealPlanEntryDelete(String id) async {}

  @override
  Future<void> enqueueDayMealUpsert(DayMealEntity meal) async {}

  @override
  Future<void> enqueueDayMealDelete(String id) async {}

  @override
  Future<void> enqueueMealPlanEntryUpsert(MealPlanEntryEntity entry) async {}

  @override
  Future<void> enqueueMealPlanEntryDelete(String id) async {}

  @override
  Future<void> enqueueActivityUpsert(Object _) async {}

  @override
  Future<void> enqueueActivityDelete(String _) async {}

  @override
  Future<void> enqueueWaterIntakeUpsert(Object _) async {}

  @override
  Future<void> enqueueWaterIntakeDelete(String _) async {}

  @override
  Future<void> enqueueUserUpsert(Object _) async {}
}
