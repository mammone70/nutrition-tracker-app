import 'dart:convert';

import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
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
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/meal_plan_utils.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';
import 'package:uuid/uuid.dart';

/// Executes Fitty Agent tool calls against local use cases (and sync).
class AgentToolExecutor {
  static const _uuid = Uuid();

  final GetEffectiveMacroTargetUsecase _getEffectiveMacros;
  final GetDailyMacroTargetUsecase _getDailyMacros;
  final SaveDailyMacroTargetUsecase _saveDailyMacros;
  final GetWeeklyMacroTargetsUsecase _getWeeklyMacros;
  final SaveWeeklyMacroTargetsUsecase _saveWeeklyMacros;
  final GetDayMealsUsecase _getDayMeals;
  final SaveDayMealsUsecase _saveDayMeals;
  final GetWeeklyMealsUsecase _getWeeklyMeals;
  final SaveWeeklyMealsUsecase _saveWeeklyMeals;
  final GetIntakeUsecase _getIntake;
  final GetUserUsecase _getUser;
  final GetWeightLogUsecase _getWeightLog;
  final AddWeightLogUsecase _addWeightLog;
  final SyncService _syncService;
  final CalorieTrackerSyncCredentials _syncCredentials;

  AgentToolExecutor({
    required GetEffectiveMacroTargetUsecase getEffectiveMacros,
    required GetDailyMacroTargetUsecase getDailyMacros,
    required SaveDailyMacroTargetUsecase saveDailyMacros,
    required GetWeeklyMacroTargetsUsecase getWeeklyMacros,
    required SaveWeeklyMacroTargetsUsecase saveWeeklyMacros,
    required GetDayMealsUsecase getDayMeals,
    required SaveDayMealsUsecase saveDayMeals,
    required GetWeeklyMealsUsecase getWeeklyMeals,
    required SaveWeeklyMealsUsecase saveWeeklyMeals,
    required GetIntakeUsecase getIntake,
    required GetUserUsecase getUser,
    required GetWeightLogUsecase getWeightLog,
    required AddWeightLogUsecase addWeightLog,
    required SyncService syncService,
    required CalorieTrackerSyncCredentials syncCredentials,
  }) : _getEffectiveMacros = getEffectiveMacros,
       _getDailyMacros = getDailyMacros,
       _saveDailyMacros = saveDailyMacros,
       _getWeeklyMacros = getWeeklyMacros,
       _saveWeeklyMacros = saveWeeklyMacros,
       _getDayMeals = getDayMeals,
       _saveDayMeals = saveDayMeals,
       _getWeeklyMeals = getWeeklyMeals,
       _saveWeeklyMeals = saveWeeklyMeals,
       _getIntake = getIntake,
       _getUser = getUser,
       _getWeightLog = getWeightLog,
       _addWeightLog = addWeightLog,
       _syncService = syncService,
       _syncCredentials = syncCredentials;

  Future<String> execute(AgentToolCall call) async {
    try {
      final result = await _dispatch(call.name, call.arguments);
      return jsonEncode(result);
    } catch (e) {
      return jsonEncode({'ok': false, 'error': e.toString()});
    }
  }

  Future<Map<String, dynamic>> _dispatch(
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      case 'get_effective_macros':
        return _getEffectiveMacrosTool(args);
      case 'set_daily_macro_target':
        return _setDailyMacros(args);
      case 'get_weekly_macro_targets':
        return _getWeeklyMacrosTool();
      case 'set_weekly_macro_target':
        return _setWeeklyMacro(args);
      case 'get_day_meal_plan':
        return _getDayMealPlan(args);
      case 'save_day_meal_plan':
        return _saveDayMealPlan(args);
      case 'get_weekly_meal_plan':
        return _getWeeklyMealPlan(args);
      case 'save_weekly_meal_plan':
        return _saveWeeklyMealPlan(args);
      case 'get_diary_day':
        return _getDiaryDay(args);
      case 'get_profile_summary':
        return _getProfileSummary();
      case 'get_weight_history':
        return _getWeightHistory(args);
      case 'log_weight':
        return _logWeight(args);
      case 'get_sync_status':
        return _getSyncStatus();
      case 'sync_now':
        return _syncNow();
      default:
        return {'ok': false, 'error': 'Unknown tool: $name'};
    }
  }

  String _today() => DateTime.now().toParsedDay();

  String _dateArg(Map<String, dynamic> args) {
    final raw = args['date'];
    if (raw is String && raw.isNotEmpty) return raw;
    return _today();
  }

  Future<Map<String, dynamic>> _getEffectiveMacrosTool(
    Map<String, dynamic> args,
  ) async {
    final date = _dateArg(args);
    final target = await _getEffectiveMacros.execute(date);
    return {
      'ok': true,
      'date': target.targetDate,
      'calories': target.calories,
      'protein_g': target.proteinG,
      'fat_g': target.fatG,
      'carbs_g': target.carbsG,
      'source': target.source.name,
    };
  }

  Future<Map<String, dynamic>> _setDailyMacros(
    Map<String, dynamic> args,
  ) async {
    final date = args['date'] as String;
    final existing = await _getDailyMacros.getByTargetDate(date);
    final entity = MacroTargetEntity(
      id: existing?.id ?? _uuid.v4(),
      targetDate: date,
      calories: (args['calories'] as num).toInt(),
      proteinG: (args['protein_g'] as num).toDouble(),
      fatG: (args['fat_g'] as num).toDouble(),
      carbsG: (args['carbs_g'] as num).toDouble(),
      updatedAt: DateTime.now().toUtc(),
    );
    await _saveDailyMacros.save(entity);
    return {'ok': true, 'id': entity.id, 'date': date};
  }

  Future<Map<String, dynamic>> _getWeeklyMacrosTool() async {
    final all = await _getWeeklyMacros.getAll();
    return {
      'ok': true,
      'targets': all
          .map(
            (t) => {
              'id': t.id,
              'day_of_week': t.dayOfWeek,
              'weekday': weekdays[t.dayOfWeek],
              'calories': t.calories,
              'protein_g': t.proteinG,
              'fat_g': t.fatG,
              'carbs_g': t.carbsG,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _setWeeklyMacro(
    Map<String, dynamic> args,
  ) async {
    final dayOfWeek = (args['day_of_week'] as num).toInt();
    final existing = await _getWeeklyMacros.getByDayOfWeek(dayOfWeek);
    final entity = WeeklyMacroTargetEntity(
      id: existing?.id ?? _uuid.v4(),
      dayOfWeek: dayOfWeek,
      calories: (args['calories'] as num).toInt(),
      proteinG: (args['protein_g'] as num).toDouble(),
      fatG: (args['fat_g'] as num).toDouble(),
      carbsG: (args['carbs_g'] as num).toDouble(),
      updatedAt: DateTime.now().toUtc(),
    );
    await _saveWeeklyMacros.save(entity);
    return {
      'ok': true,
      'id': entity.id,
      'day_of_week': dayOfWeek,
      'weekday': weekdays[dayOfWeek],
    };
  }

  Future<Map<String, dynamic>> _getDayMealPlan(
    Map<String, dynamic> args,
  ) async {
    final date = _dateArg(args);
    final meals = await _getDayMeals.getMeals(date);
    final entries = await _getDayMeals.getEntries(date);
    return {
      'ok': true,
      'date': date,
      'meals': meals.map((m) {
        final foods = entries
            .where((e) => e.dayMealId == m.id)
            .map(_entryToJson)
            .toList();
        return {
          'id': m.id,
          'name': m.name,
          'meal_index': m.mealIndex,
          'meal_time': m.mealTime,
          'foods': foods,
        };
      }).toList(),
    };
  }

  Map<String, dynamic> _entryToJson(MealPlanEntryEntity e) => {
    'id': e.id,
    'name': e.foodName,
    'brand': e.brand,
    'quantity': e.quantity,
    'unit': e.unit,
    'calories_per_100': e.caloriesPer100,
    'protein_per_100': e.proteinPer100,
    'fat_per_100': e.fatPer100,
    'carbs_per_100': e.carbsPer100,
    'calories': e.calories,
    'protein_g': e.proteinG,
    'fat_g': e.fatG,
    'carbs_g': e.carbsG,
  };

  Future<Map<String, dynamic>> _saveDayMealPlan(
    Map<String, dynamic> args,
  ) async {
    final date = args['date'] as String;
    final mealArgs = (args['meals'] as List).cast<Map<String, dynamic>>();
    final meals = <DayMealEntity>[];
    final entries = <MealPlanEntryEntity>[];
    final now = DateTime.now().toUtc();

    for (var i = 0; i < mealArgs.length; i++) {
      final m = mealArgs[i];
      final mealId = _uuid.v4();
      meals.add(
        DayMealEntity(
          id: mealId,
          planDate: date,
          mealIndex: i,
          name: m['name'] as String,
          mealTime: m['meal_time'] as String?,
          updatedAt: now,
        ),
      );
      final foods = (m['foods'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final f in foods) {
        entries.add(_foodToDayEntry(date, mealId, f, now));
      }
    }

    await _saveDayMeals.saveDay(planDate: date, meals: meals, entries: entries);
    return {
      'ok': true,
      'date': date,
      'meal_count': meals.length,
      'food_count': entries.length,
    };
  }

  MealPlanEntryEntity _foodToDayEntry(
    String date,
    String mealId,
    Map<String, dynamic> f,
    DateTime now,
  ) {
    final name = f['name'] as String;
    return MealPlanEntryEntity(
      id: _uuid.v4(),
      planDate: date,
      dayMealId: mealId,
      foodId: 'agent:${name.toLowerCase().replaceAll(' ', '-')}',
      foodName: name,
      brand: f['brand'] as String?,
      caloriesPer100: (f['calories_per_100'] as num).toDouble(),
      proteinPer100: (f['protein_per_100'] as num).toDouble(),
      fatPer100: (f['fat_per_100'] as num).toDouble(),
      carbsPer100: (f['carbs_per_100'] as num).toDouble(),
      quantity: (f['quantity'] as num).toDouble(),
      unit: (f['unit'] as String?) ?? 'g',
      updatedAt: now,
    );
  }

  Future<Map<String, dynamic>> _getWeeklyMealPlan(
    Map<String, dynamic> args,
  ) async {
    final dayOfWeek = (args['day_of_week'] as num).toInt();
    final meals = await _getWeeklyMeals.getMealsByDay(dayOfWeek);
    final entries = await _getWeeklyMeals.getEntriesForMeals(meals);
    return {
      'ok': true,
      'day_of_week': dayOfWeek,
      'weekday': weekdays[dayOfWeek],
      'meals': meals.map((m) {
        final foods = entries
            .where((e) => e.weeklyMealId == m.id)
            .map(
              (e) => {
                'id': e.id,
                'name': e.foodName,
                'brand': e.brand,
                'quantity': e.quantity,
                'unit': e.unit,
                'calories_per_100': e.caloriesPer100,
                'protein_per_100': e.proteinPer100,
                'fat_per_100': e.fatPer100,
                'carbs_per_100': e.carbsPer100,
              },
            )
            .toList();
        return {
          'id': m.id,
          'name': m.name,
          'meal_index': m.mealIndex,
          'meal_time': m.mealTime,
          'foods': foods,
        };
      }).toList(),
    };
  }

  Future<Map<String, dynamic>> _saveWeeklyMealPlan(
    Map<String, dynamic> args,
  ) async {
    final dayOfWeek = (args['day_of_week'] as num).toInt();
    final mealArgs = (args['meals'] as List).cast<Map<String, dynamic>>();
    final meals = <WeeklyMealEntity>[];
    final entries = <WeeklyMealPlanEntryEntity>[];
    final now = DateTime.now().toUtc();

    for (var i = 0; i < mealArgs.length; i++) {
      final m = mealArgs[i];
      final mealId = _uuid.v4();
      meals.add(
        WeeklyMealEntity(
          id: mealId,
          dayOfWeek: dayOfWeek,
          mealIndex: i,
          name: m['name'] as String,
          mealTime: m['meal_time'] as String?,
          updatedAt: now,
        ),
      );
      final foods = (m['foods'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final f in foods) {
        final name = f['name'] as String;
        entries.add(
          WeeklyMealPlanEntryEntity(
            id: _uuid.v4(),
            weeklyMealId: mealId,
            foodId: 'agent:${name.toLowerCase().replaceAll(' ', '-')}',
            foodName: name,
            brand: f['brand'] as String?,
            caloriesPer100: (f['calories_per_100'] as num).toDouble(),
            proteinPer100: (f['protein_per_100'] as num).toDouble(),
            fatPer100: (f['fat_per_100'] as num).toDouble(),
            carbsPer100: (f['carbs_per_100'] as num).toDouble(),
            quantity: (f['quantity'] as num).toDouble(),
            unit: (f['unit'] as String?) ?? 'g',
            updatedAt: now,
          ),
        );
      }
    }

    await _saveWeeklyMeals.saveDay(
      dayOfWeek: dayOfWeek,
      meals: meals,
      entries: entries,
    );
    return {
      'ok': true,
      'day_of_week': dayOfWeek,
      'weekday': weekdays[dayOfWeek],
      'meal_count': meals.length,
      'food_count': entries.length,
    };
  }

  Future<Map<String, dynamic>> _getDiaryDay(Map<String, dynamic> args) async {
    final dateStr = _dateArg(args);
    final parts = dateStr.split('-').map(int.parse).toList();
    final day = DateTime(parts[0], parts[1], parts[2]);

    Future<List<Map<String, dynamic>>> section(IntakeTypeEntity type) async {
      final items = switch (type) {
        IntakeTypeEntity.breakfast => await _getIntake.getBreakfastIntakeByDay(
          day,
        ),
        IntakeTypeEntity.lunch => await _getIntake.getLunchIntakeByDay(day),
        IntakeTypeEntity.dinner => await _getIntake.getDinnerIntakeByDay(day),
        IntakeTypeEntity.snack => await _getIntake.getSnackIntakeByDay(day),
      };
      return items
          .map(
            (raw) => {
              'name': raw.meal.name,
              'amount': raw.amount,
              'unit': raw.unit,
              'calories': raw.totalKcal,
              'protein_g': raw.totalProteinsGram,
              'fat_g': raw.totalFatsGram,
              'carbs_g': raw.totalCarbsGram,
              'meal': type.name,
            },
          )
          .toList();
    }

    final breakfast = await section(IntakeTypeEntity.breakfast);
    final lunch = await section(IntakeTypeEntity.lunch);
    final dinner = await section(IntakeTypeEntity.dinner);
    final snack = await section(IntakeTypeEntity.snack);
    final all = [...breakfast, ...lunch, ...dinner, ...snack];
    double sum(String key) =>
        all.fold(0.0, (s, e) => s + ((e[key] as num?)?.toDouble() ?? 0));

    return {
      'ok': true,
      'date': dateStr,
      'items': all,
      'totals': {
        'calories': sum('calories'),
        'protein_g': sum('protein_g'),
        'fat_g': sum('fat_g'),
        'carbs_g': sum('carbs_g'),
      },
    };
  }

  Future<Map<String, dynamic>> _getProfileSummary() async {
    final user = await _getUser.getUserData();
    return {
      'ok': true,
      'age_years': user.age,
      'height_cm': user.heightCM,
      'weight_kg': user.weightKG,
      'gender': user.gender.name,
      'goal': user.goal.name,
      'activity_level': user.pal.name,
      'weekly_weight_goal_kg': user.weeklyWeightGoalKg,
      'target_weight_kg': user.targetWeightKg,
      'calories_taper_enabled': user.caloriesTaperEnabled,
    };
  }

  Future<Map<String, dynamic>> _getWeightHistory(
    Map<String, dynamic> args,
  ) async {
    final limit = (args['limit'] as num?)?.toInt() ?? 14;
    final all = await _getWeightLog.getAllEntries();
    final sorted = [...all]..sort((a, b) => b.date.compareTo(a.date));
    final slice = sorted.take(limit).toList();
    return {
      'ok': true,
      'entries': slice
          .map((e) => {'date': e.date.toParsedDay(), 'weight_kg': e.weightKg})
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _logWeight(Map<String, dynamic> args) async {
    final dateStr = args['date'] as String;
    final parts = dateStr.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    final weight = (args['weight_kg'] as num).toDouble();
    await _addWeightLog.addEntry(WeightLogEntity(date: date, weightKg: weight));
    return {'ok': true, 'date': dateStr, 'weight_kg': weight};
  }

  Future<Map<String, dynamic>> _getSyncStatus() async {
    await _syncService.refreshPendingCount();
    final configured = await _syncCredentials.isConfigured();
    return {
      'ok': true,
      'configured': configured,
      'syncing': _syncService.isSyncing,
      'pending_count': _syncService.pendingCount,
      'last_sync_at': _syncService.lastSyncAt?.toIso8601String(),
      'last_error': _syncService.lastError,
    };
  }

  Future<Map<String, dynamic>> _syncNow() async {
    if (!await _syncCredentials.isConfigured()) {
      return {'ok': false, 'error': 'Calorie Tracker sync is not configured.'};
    }
    final success = await _syncService.syncNow();
    return {
      'ok': success,
      'pending_count': _syncService.pendingCount,
      'last_error': _syncService.lastError,
      'last_sync_at': _syncService.lastSyncAt?.toIso8601String(),
    };
  }
}
