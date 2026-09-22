import 'dart:convert';

import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/daily_macro_target_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/day_meals_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/ensure_custom_meal_for_plan_food.dart';
import 'package:opennutritracker/core/domain/usecase/get_effective_macro_target_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/weekly_macro_target_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/weekly_meals_usecase.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_sync_credentials.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/meal_plan_utils.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
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
  final AddIntakeUsecase _addIntake;
  final AddTrackedDayUsecase _addTrackedDay;
  final GetTrackedDayUsecase _getTrackedDay;
  final GetUserUsecase _getUser;
  final GetWeightLogUsecase _getWeightLog;
  final AddWeightLogUsecase _addWeightLog;
  final SyncService _syncService;
  final CalorieTrackerSyncCredentials _syncCredentials;
  final CustomMealDataSource _customMeals;

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
    required AddIntakeUsecase addIntake,
    required AddTrackedDayUsecase addTrackedDay,
    required GetTrackedDayUsecase getTrackedDay,
    required GetUserUsecase getUser,
    required GetWeightLogUsecase getWeightLog,
    required AddWeightLogUsecase addWeightLog,
    required SyncService syncService,
    required CalorieTrackerSyncCredentials syncCredentials,
    required CustomMealDataSource customMeals,
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
       _addIntake = addIntake,
       _addTrackedDay = addTrackedDay,
       _getTrackedDay = getTrackedDay,
       _getUser = getUser,
       _getWeightLog = getWeightLog,
       _addWeightLog = addWeightLog,
       _syncService = syncService,
       _syncCredentials = syncCredentials,
       _customMeals = customMeals;

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
      case 'set_weekly_macro_targets':
        return _setWeeklyMacrosBatch(args);
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
      case 'get_period_summary':
        return _getPeriodSummary(args);
      case 'get_remaining_macros':
        return _getRemainingMacros(args);
      case 'set_daily_macro_targets':
        return _setDailyMacrosBatch(args);
      case 'search_custom_meals':
        return _searchCustomMeals(args);
      case 'log_intake':
        return _logIntake(args);
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
    final entity = await _upsertWeeklyMacro(args);
    return {
      'ok': true,
      'id': entity.id,
      'day_of_week': entity.dayOfWeek,
      'weekday': weekdays[entity.dayOfWeek],
    };
  }

  Future<Map<String, dynamic>> _setWeeklyMacrosBatch(
    Map<String, dynamic> args,
  ) async {
    final raw = args['targets'];
    if (raw is! List || raw.isEmpty) {
      return {'ok': false, 'error': 'targets must be a non-empty array'};
    }
    final saved = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) {
        return {'ok': false, 'error': 'each target must be an object'};
      }
      final entity = await _upsertWeeklyMacro(Map<String, dynamic>.from(item));
      saved.add({
        'id': entity.id,
        'day_of_week': entity.dayOfWeek,
        'weekday': weekdays[entity.dayOfWeek],
        'calories': entity.calories,
        'protein_g': entity.proteinG,
        'fat_g': entity.fatG,
        'carbs_g': entity.carbsG,
      });
    }
    return {'ok': true, 'saved': saved};
  }

  Future<WeeklyMacroTargetEntity> _upsertWeeklyMacro(
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
    return entity;
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
    await _ensureCustomMealsForDayEntries(entries);
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

  Future<void> _ensureCustomMealsForDayEntries(
    List<MealPlanEntryEntity> entries,
  ) async {
    for (final entry in entries) {
      await ensureCustomMealForMealPlanEntryEntity(
        customMeals: _customMeals,
        entry: entry,
      );
    }
  }

  Future<void> _ensureCustomMealsForWeeklyEntries(
    List<WeeklyMealPlanEntryEntity> entries,
  ) async {
    for (final entry in entries) {
      await ensureCustomMealForPlanFood(
        customMeals: _customMeals,
        name: entry.foodName,
        brand: entry.brand,
        caloriesPer100: entry.caloriesPer100,
        proteinPer100: entry.proteinPer100,
        fatPer100: entry.fatPer100,
        carbsPer100: entry.carbsPer100,
        unit: entry.unit,
        preferredCode: entry.foodId,
      );
    }
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
    await _ensureCustomMealsForWeeklyEntries(entries);
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

  Future<Map<String, dynamic>> _getPeriodSummary(
    Map<String, dynamic> args,
  ) async {
    final startStr = args['start_date'] as String;
    final endStr = args['end_date'] as String? ?? _today();
    final startParts = startStr.split('-').map(int.parse).toList();
    final endParts = endStr.split('-').map(int.parse).toList();
    final start = DateTime(startParts[0], startParts[1], startParts[2]);
    final end = DateTime(endParts[0], endParts[1], endParts[2]);
    if (end.isBefore(start)) {
      return {'ok': false, 'error': 'end_date must be on or after start_date'};
    }

    final tracked = await _getTrackedDay.getTrackedDaysByRange(start, end);
    final days = <Map<String, dynamic>>[];
    var sumCal = 0.0, sumP = 0.0, sumF = 0.0, sumC = 0.0;
    for (final day in tracked) {
      final cal = day.caloriesTracked;
      final p = day.proteinTracked ?? 0;
      final f = day.fatTracked ?? 0;
      final c = day.carbsTracked ?? 0;
      sumCal += cal;
      sumP += p;
      sumF += f;
      sumC += c;
      days.add({
        'date': day.day.toParsedDay(),
        'calories': cal,
        'protein_g': p,
        'fat_g': f,
        'carbs_g': c,
        'calorie_goal': day.calorieGoal,
      });
    }
    final n = days.isEmpty ? 1 : days.length;

    final weights = await _getWeightLog.getEntriesInRange(start, end);
    final weightEntries = [...weights]..sort((a, b) => a.date.compareTo(b.date));
    final weightAvg = weightEntries.isEmpty
        ? null
        : weightEntries.fold<double>(0, (s, e) => s + e.weightKg) /
              weightEntries.length;

    return {
      'ok': true,
      'start_date': startStr,
      'end_date': endStr,
      'tracked_day_count': days.length,
      'days': days,
      'averages': {
        'calories': sumCal / n,
        'protein_g': sumP / n,
        'fat_g': sumF / n,
        'carbs_g': sumC / n,
      },
      'totals': {
        'calories': sumCal,
        'protein_g': sumP,
        'fat_g': sumF,
        'carbs_g': sumC,
      },
      'weight': {
        'entries': weightEntries
            .map(
              (e) => {'date': e.date.toParsedDay(), 'weight_kg': e.weightKg},
            )
            .toList(),
        'average_kg': weightAvg,
        'entry_count': weightEntries.length,
      },
    };
  }

  Future<Map<String, dynamic>> _getRemainingMacros(
    Map<String, dynamic> args,
  ) async {
    final dateStr = _dateArg(args);
    final target = await _getEffectiveMacros.execute(dateStr);
    final diary = await _getDiaryDay({'date': dateStr});
    final totals = diary['totals'] as Map<String, dynamic>;
    final loggedCal = (totals['calories'] as num).toDouble();
    final loggedP = (totals['protein_g'] as num).toDouble();
    final loggedF = (totals['fat_g'] as num).toDouble();
    final loggedC = (totals['carbs_g'] as num).toDouble();
    return {
      'ok': true,
      'date': dateStr,
      'targets': {
        'calories': target.calories,
        'protein_g': target.proteinG,
        'fat_g': target.fatG,
        'carbs_g': target.carbsG,
        'source': target.source.name,
      },
      'logged': {
        'calories': loggedCal,
        'protein_g': loggedP,
        'fat_g': loggedF,
        'carbs_g': loggedC,
      },
      'remaining': {
        'calories': target.calories - loggedCal,
        'protein_g': target.proteinG - loggedP,
        'fat_g': target.fatG - loggedF,
        'carbs_g': target.carbsG - loggedC,
      },
    };
  }

  Future<Map<String, dynamic>> _setDailyMacrosBatch(
    Map<String, dynamic> args,
  ) async {
    final targets = (args['targets'] as List).cast<Map<String, dynamic>>();
    final saved = <String>[];
    for (final t in targets) {
      final date = t['date'] as String;
      final existing = await _getDailyMacros.getByTargetDate(date);
      final entity = MacroTargetEntity(
        id: existing?.id ?? _uuid.v4(),
        targetDate: date,
        calories: (t['calories'] as num).toInt(),
        proteinG: (t['protein_g'] as num).toDouble(),
        fatG: (t['fat_g'] as num).toDouble(),
        carbsG: (t['carbs_g'] as num).toDouble(),
        updatedAt: DateTime.now().toUtc(),
      );
      await _saveDailyMacros.save(entity);
      saved.add(date);
    }
    return {'ok': true, 'saved_dates': saved, 'count': saved.length};
  }

  Future<Map<String, dynamic>> _searchCustomMeals(
    Map<String, dynamic> args,
  ) async {
    final query = (args['query'] as String).trim().toLowerCase();
    final limit = (args['limit'] as num?)?.toInt() ?? 10;
    if (query.isEmpty) {
      return {'ok': true, 'results': <Map<String, dynamic>>[]};
    }
    final matches = _customMeals
        .getAllCustomMeals()
        .where((m) {
          final name = (m.name ?? '').toLowerCase();
          final brand = (m.brands ?? '').toLowerCase();
          return name.contains(query) || brand.contains(query);
        })
        .take(limit)
        .map((m) {
          final n = m.nutriments;
          return {
            'name': m.name,
            'brand': m.brands,
            'code': m.code,
            'calories_per_100': n.energyKcal100,
            'protein_per_100': n.proteins100,
            'fat_per_100': n.fat100,
            'carbs_per_100': n.carbohydrates100,
            'unit': m.mealUnit ?? 'g',
          };
        })
        .toList();
    return {'ok': true, 'query': query, 'results': matches};
  }

  Future<Map<String, dynamic>> _logIntake(Map<String, dynamic> args) async {
    final dateStr = args['date'] as String;
    final parts = dateStr.split('-').map(int.parse).toList();
    final day = DateTime(parts[0], parts[1], parts[2]);
    final mealTypeRaw = (args['meal_type'] as String).toLowerCase().trim();
    final type = switch (mealTypeRaw) {
      'breakfast' => IntakeTypeEntity.breakfast,
      'lunch' => IntakeTypeEntity.lunch,
      'dinner' => IntakeTypeEntity.dinner,
      'snack' => IntakeTypeEntity.snack,
      _ => throw ArgumentError('meal_type must be breakfast|lunch|dinner|snack'),
    };
    final quantity = (args['quantity'] as num).toDouble();
    final unit = (args['unit'] as String?) ?? 'g';
    final cal100 = (args['calories_per_100'] as num).toDouble();
    final p100 = (args['protein_per_100'] as num).toDouble();
    final f100 = (args['fat_per_100'] as num).toDouble();
    final c100 = (args['carbs_per_100'] as num).toDouble();
    final name = args['name'] as String;
    final brand = args['brand'] as String?;

    final meal = MealEntity(
      code: IdGenerator.getUniqueID(),
      name: name,
      brands: brand,
      url: null,
      mealQuantity: null,
      mealUnit: unit,
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      nutriments: MealNutrimentsEntity(
        energyKcal100: cal100,
        carbohydrates100: c100,
        fat100: f100,
        proteins100: p100,
        sugars100: null,
        saturatedFat100: null,
        fiber100: null,
      ),
      source: MealSourceEntity.custom,
    );
    final intake = IntakeEntity(
      id: IdGenerator.getUniqueID(),
      unit: unit,
      amount: quantity,
      type: type,
      meal: meal,
      dateTime: DateTime(day.year, day.month, day.day, 12),
    );
    await _addIntake.addIntake(intake);

    final target = await _getEffectiveMacros.execute(dateStr);
    final hasDay = await _addTrackedDay.hasTrackedDay(day);
    if (!hasDay) {
      await _addTrackedDay.addNewTrackedDay(
        day,
        target.calories.toDouble(),
        target.carbsG,
        target.fatG,
        target.proteinG,
      );
    }
    await _addTrackedDay.addDayCaloriesTracked(day, intake.totalKcal);
    await _addTrackedDay.addDayMacrosTracked(
      day,
      carbsTracked: intake.totalCarbsGram,
      fatTracked: intake.totalFatsGram,
      proteinTracked: intake.totalProteinsGram,
    );

    await ensureCustomMealForPlanFood(
      customMeals: _customMeals,
      name: name,
      brand: brand,
      caloriesPer100: cal100,
      proteinPer100: p100,
      fatPer100: f100,
      carbsPer100: c100,
      unit: unit,
    );

    return {
      'ok': true,
      'date': dateStr,
      'meal_type': type.name,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'calories': intake.totalKcal,
      'protein_g': intake.totalProteinsGram,
      'fat_g': intake.totalFatsGram,
      'carbs_g': intake.totalCarbsGram,
    };
  }

  Future<Map<String, dynamic>> _getWeightHistory(
    Map<String, dynamic> args,
  ) async {
    final startStr = args['start_date'] as String?;
    final endStr = args['end_date'] as String?;
    List<WeightLogEntity> slice;
    if (startStr != null && startStr.isNotEmpty) {
      final startParts = startStr.split('-').map(int.parse).toList();
      final endParts = (endStr ?? _today()).split('-').map(int.parse).toList();
      final start = DateTime(startParts[0], startParts[1], startParts[2]);
      final end = DateTime(endParts[0], endParts[1], endParts[2]);
      slice = await _getWeightLog.getEntriesInRange(start, end);
      slice = [...slice]..sort((a, b) => b.date.compareTo(a.date));
    } else {
      final limit = (args['limit'] as num?)?.toInt() ?? 14;
      final all = await _getWeightLog.getAllEntries();
      final sorted = [...all]..sort((a, b) => b.date.compareTo(a.date));
      slice = sorted.take(limit).toList();
    }
    final avg = slice.isEmpty
        ? null
        : slice.fold<double>(0, (s, e) => s + e.weightKg) / slice.length;
    return {
      'ok': true,
      'entries': slice
          .map((e) => {'date': e.date.toParsedDay(), 'weight_kg': e.weightKg})
          .toList(),
      'average_kg': avg,
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
