import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/daily_macro_target_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/day_meals_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_effective_macro_target_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/weekly_macro_target_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/weekly_meals_usecase.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_sync_credentials.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_tool_executor.dart';

import '../helpers/fake_hive_db_provider.dart';
import '../helpers/fake_sync_service.dart';
import '../helpers/hive_test_setup.dart';

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
  final Map<String, MacroTargetEntity> byDate = {};

  @override
  Future<MacroTargetEntity?> getByTargetDate(String targetDate) async =>
      byDate[targetDate];
}

class _FakeSaveDaily implements SaveDailyMacroTargetUsecase {
  MacroTargetEntity? last;
  final List<MacroTargetEntity> saved = [];

  @override
  Future<void> save(MacroTargetEntity target) async {
    last = target;
    saved.add(target);
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
  noSuchMethod(Invocation invocation) =>
      Future<List<IntakeEntity>>.value(<IntakeEntity>[]);
}

class _FakeAddIntake implements AddIntakeUsecase {
  IntakeEntity? last;

  @override
  Future<void> addIntake(IntakeEntity intakeEntity) async {
    last = intakeEntity;
  }

  @override
  noSuchMethod(Invocation invocation) => null;
}

class _FakeAddTrackedDay implements AddTrackedDayUsecase {
  final List<String> calorieAdds = [];
  final List<String> macroAdds = [];

  @override
  Future<bool> hasTrackedDay(DateTime day) async => true;

  @override
  Future<void> addNewTrackedDay(
    DateTime day,
    double totalKcalGoal,
    double totalCarbsGoal,
    double totalFatGoal,
    double totalProteinGoal,
  ) async {}

  @override
  Future<void> addDayCaloriesTracked(DateTime day, double calories) async {
    calorieAdds.add('$day:$calories');
  }

  @override
  Future<void> addDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {
    macroAdds.add('$day:$proteinTracked/$fatTracked/$carbsTracked');
  }

  @override
  noSuchMethod(Invocation invocation) => null;
}

class _FakeGetTrackedDay implements GetTrackedDayUsecase {
  List<TrackedDayEntity> range = [];

  @override
  Future<TrackedDayEntity?> getTrackedDay(DateTime day) async => null;

  @override
  Future<List<TrackedDayEntity>> getTrackedDaysByRange(
    DateTime start,
    DateTime end,
  ) async => range;
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
  List<WeightLogEntity> range = [];

  @override
  Future<List<WeightLogEntity>> getAllEntries() async => range;

  @override
  Future<List<WeightLogEntity>> getEntriesInRange(
    DateTime from,
    DateTime to,
  ) async => range;
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
  late Box<MealDBO> customMealBox;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('.');
    registerHiveAdaptersOnce();
  });

  setUp(() async {
    customMealBox = await Hive.openBox<MealDBO>(
      'fitty_agent_custom_meal_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await customMealBox.deleteFromDisk();
  });

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
      addIntake: _FakeAddIntake(),
      addTrackedDay: _FakeAddTrackedDay(),
      getTrackedDay: _FakeGetTrackedDay(),
      getUser: _FakeUser(),
      getWeightLog: _FakeWeightGet(),
      addWeightLog: _FakeWeightAdd(),
      syncService: FakeSyncService(),
      syncCredentials: _FakeSyncCredentials(),
      customMeals: CustomMealDataSource(
        FakeHiveDBProvider(customMealBox: customMealBox),
      ),
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

    final batch =
        jsonDecode(
              await executor.execute(
                const AgentToolCall(
                  id: '4',
                  name: 'set_weekly_macro_targets',
                  arguments: {
                    'targets': [
                      {
                        'day_of_week': 0,
                        'calories': 4300,
                        'protein_g': 225,
                        'fat_g': 80,
                        'carbs_g': 670,
                      },
                      {
                        'day_of_week': 1,
                        'calories': 3500,
                        'protein_g': 225,
                        'fat_g': 80,
                        'carbs_g': 470,
                      },
                    ],
                  },
                ),
              ),
            )
            as Map<String, dynamic>;
    expect(batch['ok'], true);
    expect((batch['saved'] as List).length, 2);
  });

  test('period summary, remaining macros, batch daily, search, log', () async {
    final getDaily = _FakeGetDaily();
    final saveDaily = _FakeSaveDaily();
    final tracked = _FakeGetTrackedDay()
      ..range = [
        TrackedDayEntity(
          day: DateTime(2026, 9, 15),
          calorieGoal: 4300,
          caloriesTracked: 4100,
          proteinTracked: 220,
          fatTracked: 78,
          carbsTracked: 500,
        ),
        TrackedDayEntity(
          day: DateTime(2026, 9, 16),
          calorieGoal: 4300,
          caloriesTracked: 4500,
          proteinTracked: 230,
          fatTracked: 82,
          carbsTracked: 560,
        ),
      ];
    final weights = _FakeWeightGet()
      ..range = [
        WeightLogEntity(date: DateTime(2026, 9, 15), weightKg: 90),
        WeightLogEntity(date: DateTime(2026, 9, 16), weightKg: 90.4),
      ];
    final addIntake = _FakeAddIntake();
    final addTracked = _FakeAddTrackedDay();

    await customMealBox.add(
      MealDBO(
        code: 'beef',
        name: '80/20 ground beef cooked',
        brands: null,
        thumbnailImageUrl: null,
        mainImageUrl: null,
        url: null,
        mealQuantity: '100',
        mealUnit: 'g',
        servingQuantity: null,
        servingUnit: 'g',
        servingSize: null,
        nutriments: MealNutrimentsDBO(
          energyKcal100: 270,
          carbohydrates100: 0,
          fat100: 20,
          proteins100: 25,
          sugars100: null,
          saturatedFat100: null,
          fiber100: null,
        ),
        source: MealSourceDBO.custom,
      ),
    );

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
      addIntake: addIntake,
      addTrackedDay: addTracked,
      getTrackedDay: tracked,
      getUser: _FakeUser(),
      getWeightLog: weights,
      addWeightLog: _FakeWeightAdd(),
      syncService: FakeSyncService(),
      syncCredentials: _FakeSyncCredentials(),
      customMeals: CustomMealDataSource(
        FakeHiveDBProvider(customMealBox: customMealBox),
      ),
    );

    final period =
        jsonDecode(
              await executor.execute(
                const AgentToolCall(
                  id: 'p1',
                  name: 'get_period_summary',
                  arguments: {
                    'start_date': '2026-09-15',
                    'end_date': '2026-09-16',
                  },
                ),
              ),
            )
            as Map<String, dynamic>;
    expect(period['ok'], true);
    expect(period['tracked_day_count'], 2);
    expect((period['averages'] as Map)['calories'], 4300);
    expect((period['weight'] as Map)['average_kg'], closeTo(90.2, 0.01));

    final remaining =
        jsonDecode(
              await executor.execute(
                const AgentToolCall(
                  id: 'r1',
                  name: 'get_remaining_macros',
                  arguments: {'date': '2026-09-16'},
                ),
              ),
            )
            as Map<String, dynamic>;
    expect(remaining['ok'], true);
    expect((remaining['targets'] as Map)['calories'], 2000);
    expect((remaining['logged'] as Map)['calories'], 0);
    expect((remaining['remaining'] as Map)['calories'], 2000);

    final dailyBatch =
        jsonDecode(
              await executor.execute(
                const AgentToolCall(
                  id: 'b1',
                  name: 'set_daily_macro_targets',
                  arguments: {
                    'targets': [
                      {
                        'date': '2026-09-22',
                        'calories': 4300,
                        'protein_g': 225,
                        'fat_g': 80,
                        'carbs_g': 670,
                      },
                      {
                        'date': '2026-09-23',
                        'calories': 3500,
                        'protein_g': 225,
                        'fat_g': 80,
                        'carbs_g': 470,
                      },
                    ],
                  },
                ),
              ),
            )
            as Map<String, dynamic>;
    expect(dailyBatch['ok'], true);
    expect(dailyBatch['count'], 2);
    expect(saveDaily.saved.length, 2);

    final search =
        jsonDecode(
              await executor.execute(
                const AgentToolCall(
                  id: 's1',
                  name: 'search_custom_meals',
                  arguments: {'query': 'ground beef'},
                ),
              ),
            )
            as Map<String, dynamic>;
    expect(search['ok'], true);
    expect((search['results'] as List).length, 1);
    expect((search['results'] as List).first['calories_per_100'], 270);

    final logged =
        jsonDecode(
              await executor.execute(
                const AgentToolCall(
                  id: 'l1',
                  name: 'log_intake',
                  arguments: {
                    'date': '2026-09-16',
                    'meal_type': 'dinner',
                    'name': '80/20 ground beef cooked',
                    'quantity': 200,
                    'unit': 'g',
                    'calories_per_100': 270,
                    'protein_per_100': 25,
                    'fat_per_100': 20,
                    'carbs_per_100': 0,
                  },
                ),
              ),
            )
            as Map<String, dynamic>;
    expect(logged['ok'], true);
    expect(logged['calories'], 540);
    expect(addIntake.last?.amount, 200);
    expect(addTracked.calorieAdds, isNotEmpty);
  });
}
