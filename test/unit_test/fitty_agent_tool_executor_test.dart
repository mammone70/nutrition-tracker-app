import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/daily_macro_target_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/day_meals_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_effective_macro_target_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/weekly_macro_target_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/weekly_meals_usecase.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_sync_credentials.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_tool_executor.dart';

import '../helpers/fake_sync_service.dart';

class _FakeEffectiveMacros implements GetEffectiveMacroTargetUsecase {
  @override
  Future<EffectiveMacroTarget> execute(String targetDate) async {
    return EffectiveMacroTarget(
      targetDate: targetDate,
      calories: 2000,
      proteinG: 150,
      fatG: 60,
      carbsG: 200,
      source: MacroTargetSource.weekly,
      weeklyDayOfWeek: 0,
    );
  }
}

class _FakeGetDaily implements GetDailyMacroTargetUsecase {
  MacroTargetEntity? stored;

  @override
  Future<MacroTargetEntity?> getByTargetDate(String targetDate) async =>
      stored?.targetDate == targetDate ? stored : null;
}

class _FakeSaveDaily implements SaveDailyMacroTargetUsecase {
  MacroTargetEntity? last;

  @override
  Future<void> save(MacroTargetEntity target) async {
    last = target;
  }

  @override
  Future<void> delete(String id) async {}
}

class _FakeGetWeekly implements GetWeeklyMacroTargetsUsecase {
  @override
  Future<List<WeeklyMacroTargetEntity>> getAll() async => [
    WeeklyMacroTargetEntity(
      id: 'w1',
      dayOfWeek: 0,
      calories: 2100,
      proteinG: 160,
      fatG: 65,
      carbsG: 210,
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  ];

  @override
  Future<WeeklyMacroTargetEntity?> getByDayOfWeek(int dayOfWeek) async => null;
}

class _FakeSaveWeekly implements SaveWeeklyMacroTargetsUsecase {
  WeeklyMacroTargetEntity? last;

  @override
  Future<void> save(WeeklyMacroTargetEntity target) async {
    last = target;
  }

  @override
  Future<void> saveAll(List<WeeklyMacroTargetEntity> targets) async {}
}

class _FakeDayMealsGet implements GetDayMealsUsecase {
  @override
  Future<List<DayMealEntity>> getMeals(String planDate) async => [];

  @override
  Future<List<MealPlanEntryEntity>> getEntries(String planDate) async => [];
}

class _FakeDayMealsSave implements SaveDayMealsUsecase {
  @override
  Future<void> saveDay({
    required String planDate,
    required List<DayMealEntity> meals,
    required List<MealPlanEntryEntity> entries,
  }) async {}
}

class _FakeWeeklyMealsGet implements GetWeeklyMealsUsecase {
  @override
  Future<List<WeeklyMealEntity>> getMealsByDay(int dayOfWeek) async => [];

  @override
  Future<List<WeeklyMealPlanEntryEntity>> getEntriesForMeals(
    List<WeeklyMealEntity> meals,
  ) async => [];

  @override
  Future<List<WeeklyMealEntity>> getAllMeals() async => [];

  @override
  Future<List<WeeklyMealPlanEntryEntity>> getAllEntries() async => [];
}

class _FakeWeeklyMealsSave implements SaveWeeklyMealsUsecase {
  @override
  Future<void> saveDay({
    required int dayOfWeek,
    required List<WeeklyMealEntity> meals,
    required List<WeeklyMealPlanEntryEntity> entries,
  }) async {}
}

class _FakeIntake implements GetIntakeUsecase {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeUser implements GetUserUsecase {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();

  @override
  Future<UserEntity> getUserData() async => throw UnimplementedError();

  @override
  Future<bool> hasUserData() async => true;
}

class _FakeWeightGet implements GetWeightLogUsecase {
  @override
  Future<List<WeightLogEntity>> getAllEntries() async => [];

  @override
  Future<List<WeightLogEntity>> getEntriesInRange(
    DateTime from,
    DateTime to,
  ) async => [];
}

class _FakeWeightAdd implements AddWeightLogUsecase {
  @override
  Future<void> addEntry(WeightLogEntity entry) async {}
}

class _FakeSyncCredentials implements CalorieTrackerSyncCredentials {
  @override
  noSuchMethod(Invocation invocation) => null;

  @override
  Future<bool> isConfigured() async => true;
}

void main() {
  test('get_effective_macros and set_daily_macro_target', () async {
    final getDaily = _FakeGetDaily();
    final saveDaily = _FakeSaveDaily();

    final executor = AgentToolExecutor(
      getEffectiveMacros: _FakeEffectiveMacros(),
      getDailyMacros: getDaily,
      saveDailyMacros: saveDaily,
      getWeeklyMacros: _FakeGetWeekly(),
      saveWeeklyMacros: _FakeSaveWeekly(),
      getDayMeals: _FakeDayMealsGet(),
      saveDayMeals: _FakeDayMealsSave(),
      getWeeklyMeals: _FakeWeeklyMealsGet(),
      saveWeeklyMeals: _FakeWeeklyMealsSave(),
      getIntake: _FakeIntake(),
      getUser: _FakeUser(),
      getWeightLog: _FakeWeightGet(),
      addWeightLog: _FakeWeightAdd(),
      syncService: FakeSyncService(),
      syncCredentials: _FakeSyncCredentials(),
    );

    final macros =
        jsonDecode(
              await executor.execute(
                const AgentToolCall(
                  id: '1',
                  name: 'get_effective_macros',
                  arguments: {'date': '2026-09-16'},
                ),
              ),
            )
            as Map<String, dynamic>;
    expect(macros['ok'], true);
    expect(macros['calories'], 2000);

    final saved =
        jsonDecode(
              await executor.execute(
                const AgentToolCall(
                  id: '2',
                  name: 'set_daily_macro_target',
                  arguments: {
                    'date': '2026-09-16',
                    'calories': 1800,
                    'protein_g': 140,
                    'fat_g': 55,
                    'carbs_g': 180,
                  },
                ),
              ),
            )
            as Map<String, dynamic>;
    expect(saved['ok'], true);
    expect(saveDaily.last?.calories, 1800);

    final weekly =
        jsonDecode(
              await executor.execute(
                const AgentToolCall(
                  id: '3',
                  name: 'get_weekly_macro_targets',
                  arguments: {},
                ),
              ),
            )
            as Map<String, dynamic>;
    expect(weekly['targets'], isNotEmpty);
  });
}
