import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/body_weight_unit_entity.dart';
import 'package:opennutritracker/core/domain/entity/calories_profile_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/water_intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_water_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/confirm_meal_plan_to_diary_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/day_meals_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_water_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_water_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_user_activity_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_effective_macro_target_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_effective_meal_plan_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_activity_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_weight_log_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/materialize_meal_plan_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_user_activity_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/waist_log_usecase.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/calc/macro_calc.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_plan_utils.dart';
import 'package:opennutritracker/core/utils/moving_average.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:uuid/uuid.dart';

part 'home_event.dart';

part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  static const _uuid = Uuid();

  final GetConfigUsecase _getConfigUsecase;
  final AddConfigUsecase _addConfigUsecase;
  final GetIntakeUsecase _getIntakeUsecase;
  final DeleteIntakeUsecase _deleteIntakeUsecase;
  final UpdateIntakeUsecase _updateIntakeUsecase;
  final GetUserActivityUsecase _getUserActivityUsecase;
  final DeleteUserActivityUsecase _deleteUserActivityUsecase;
  final AddTrackedDayUsecase _addTrackedDayUseCase;
  final GetKcalGoalUsecase _getKcalGoalUsecase;
  final GetMacroGoalUsecase _getMacroGoalUsecase;
  final UpdateUserActivityUsecase _updateUserActivityUsecase;
  final GetUserUsecase _getUserUsecase;
  final GetWaterIntakeUsecase _getWaterIntakeUsecase;
  final AddWaterIntakeUsecase _addWaterIntakeUsecase;
  final DeleteWaterIntakeUsecase _deleteWaterIntakeUsecase;
  final GetEffectiveMealPlanUsecase _getEffectiveMealPlanUsecase;
  final GetEffectiveMacroTargetUsecase _getEffectiveMacroTargetUsecase;
  final ConfirmMealPlanToDiaryUsecase _confirmMealPlanToDiaryUsecase;
  final UnconfirmMealPlanFoodUsecase _unconfirmMealPlanFoodUsecase;
  final SaveDayMealsUsecase _saveDayMealsUsecase;
  final MaterializeWeeklyToDayUsecase _materializeWeeklyToDayUsecase;
  final GetDayMealsUsecase _getDayMealsUsecase;
  final GetWeightLogUsecase _getWeightLogUsecase;
  final GetWaistLogUsecase _getWaistLogUsecase;

  DateTime currentDay = DateTime.now();

  HomeBloc(
    this._getConfigUsecase,
    this._addConfigUsecase,
    this._getIntakeUsecase,
    this._deleteIntakeUsecase,
    this._updateIntakeUsecase,
    this._getUserActivityUsecase,
    this._deleteUserActivityUsecase,
    this._addTrackedDayUseCase,
    this._getKcalGoalUsecase,
    this._getMacroGoalUsecase,
    this._updateUserActivityUsecase,
    this._getUserUsecase,
    this._getWaterIntakeUsecase,
    this._addWaterIntakeUsecase,
    this._deleteWaterIntakeUsecase,
    this._getEffectiveMealPlanUsecase,
    this._getEffectiveMacroTargetUsecase,
    this._confirmMealPlanToDiaryUsecase,
    this._unconfirmMealPlanFoodUsecase,
    this._saveDayMealsUsecase,
    this._materializeWeeklyToDayUsecase,
    this._getDayMealsUsecase,
    this._getWeightLogUsecase,
    this._getWaistLogUsecase,
  ) : super(HomeInitial()) {
    on<LoadItemsEvent>((event, emit) async {
      emit(HomeLoadingState());

      final configData = await _getConfigUsecase.getConfig();
      final dayStartOffsetHours = configData.dayStartOffsetHours;
      final dayStartOffsetMinutes = configData.dayStartOffsetMinutes;
      // #139: the bloc's "current day" is the logical day, so day-change
      // detection on app resume respects the user's configured boundary.
      // The follow-up to #139 routes the boundary through total minutes
      // so a 04:30 setting is honoured exactly.
      currentDay = DayBoundaryCalc.currentLogicalDayMinutes(
        configData.dayStartOffsetTotalMinutes,
      );
      final usesImperialUnits = configData.usesImperialFoodUnits;
      final bodyWeightUnit = configData.bodyWeightUnit;
      final showDisclaimerDialog = !configData.hasAcceptedDisclaimer;
      final showMealMacros = configData.showMealMacros;
      final showActivityTracking = configData.showActivityTracking;

      final breakfastIntakeList = await _getIntakeUsecase
          .getTodayBreakfastIntake(
            dayStartOffsetHours: dayStartOffsetHours,
            dayStartOffsetMinutes: dayStartOffsetMinutes,
          );
      final totalBreakfastKcal = getTotalKcal(breakfastIntakeList);
      final totalBreakfastCarbs = getTotalCarbs(breakfastIntakeList);
      final totalBreakfastFats = getTotalFats(breakfastIntakeList);
      final totalBreakfastProteins = getTotalProteins(breakfastIntakeList);

      final lunchIntakeList = await _getIntakeUsecase.getTodayLunchIntake(
        dayStartOffsetHours: dayStartOffsetHours,
        dayStartOffsetMinutes: dayStartOffsetMinutes,
      );
      final totalLunchKcal = getTotalKcal(lunchIntakeList);
      final totalLunchCarbs = getTotalCarbs(lunchIntakeList);
      final totalLunchFats = getTotalFats(lunchIntakeList);
      final totalLunchProteins = getTotalProteins(lunchIntakeList);

      final dinnerIntakeList = await _getIntakeUsecase.getTodayDinnerIntake(
        dayStartOffsetHours: dayStartOffsetHours,
        dayStartOffsetMinutes: dayStartOffsetMinutes,
      );
      final totalDinnerKcal = getTotalKcal(dinnerIntakeList);
      final totalDinnerCarbs = getTotalCarbs(dinnerIntakeList);
      final totalDinnerFats = getTotalFats(dinnerIntakeList);
      final totalDinnerProteins = getTotalProteins(dinnerIntakeList);

      final snackIntakeList = await _getIntakeUsecase.getTodaySnackIntake(
        dayStartOffsetHours: dayStartOffsetHours,
        dayStartOffsetMinutes: dayStartOffsetMinutes,
      );
      final totalSnackKcal = getTotalKcal(snackIntakeList);
      final totalSnackCarbs = getTotalCarbs(snackIntakeList);
      final totalSnackFats = getTotalFats(snackIntakeList);
      final totalSnackProteins = getTotalProteins(snackIntakeList);

      final totalKcalIntake =
          totalBreakfastKcal +
          totalLunchKcal +
          totalDinnerKcal +
          totalSnackKcal;
      final totalCarbsIntake =
          totalBreakfastCarbs +
          totalLunchCarbs +
          totalDinnerCarbs +
          totalSnackCarbs;
      final totalFatsIntake =
          totalBreakfastFats +
          totalLunchFats +
          totalDinnerFats +
          totalSnackFats;
      final totalProteinsIntake =
          totalBreakfastProteins +
          totalLunchProteins +
          totalDinnerProteins +
          totalSnackProteins;

      final userActivities = await _getUserActivityUsecase.getTodayUserActivity(
        dayStartOffsetHours: dayStartOffsetHours,
        dayStartOffsetMinutes: dayStartOffsetMinutes,
      );
      final totalKcalActivities = userActivities
          .map((activity) => activity.burnedKcal)
          .toList()
          .sum;

      final waterIntakes = await _getWaterIntakeUsecase.getTodayEntries(
        dayStartOffsetTotalMinutes: configData.dayStartOffsetTotalMinutes,
      );
      final totalWaterMl = waterIntakes
          .map((entry) => entry.amountMl)
          .fold<int>(0, (sum, ml) => sum + ml);

      final user = await _getUserUsecase.getUserData();
      final planDate = currentDay.toParsedDay();
      final mealPlan = await _getEffectiveMealPlanUsecase.execute(planDate);
      final scheduledMacros = await _getEffectiveMacroTargetUsecase.execute(
        planDate,
      );

      double totalKcalGoal;
      double totalCarbsGoal;
      double totalFatsGoal;
      double totalProteinsGoal;
      if (scheduledMacros.calories > 0) {
        totalKcalGoal = scheduledMacros.calories.toDouble();
        totalCarbsGoal = scheduledMacros.carbsG;
        totalFatsGoal = scheduledMacros.fatG;
        totalProteinsGoal = scheduledMacros.proteinG;
      } else {
        totalKcalGoal = await _getKcalGoalUsecase.getKcalGoal(userEntity: user);
        totalCarbsGoal = await _getMacroGoalUsecase.getCarbsGoal(totalKcalGoal);
        totalFatsGoal = await _getMacroGoalUsecase.getFatsGoal(totalKcalGoal);
        totalProteinsGoal = await _getMacroGoalUsecase.getProteinsGoal(
          totalKcalGoal,
        );
      }

      final plannedKcal = mealPlan.meals.fold<double>(
        0,
        (sum, meal) =>
            sum + meal.entries.fold<double>(0, (s, e) => s + e.calories),
      );
      final plannedProtein = mealPlan.meals.fold<double>(
        0,
        (sum, meal) =>
            sum + meal.entries.fold<double>(0, (s, e) => s + e.proteinG),
      );
      final plannedFat = mealPlan.meals.fold<double>(
        0,
        (sum, meal) => sum + meal.entries.fold<double>(0, (s, e) => s + e.fatG),
      );
      final plannedCarbs = mealPlan.meals.fold<double>(
        0,
        (sum, meal) =>
            sum + meal.entries.fold<double>(0, (s, e) => s + e.carbsG),
      );

      final confirmedPlanFoodIntakeIds = _confirmMealPlanToDiaryUsecase
          .confirmedIntakeIdsForDate(currentDay);

      final dayOnly = DateTime(
        currentDay.year,
        currentDay.month,
        currentDay.day,
      );
      final rangeFrom = dayOnly.subtract(const Duration(days: 13));
      final weightLogs = await _getWeightLogUsecase.getEntriesInRange(
        rangeFrom,
        dayOnly,
      );
      final waistLogs = await _getWaistLogUsecase.getEntriesInRange(
        rangeFrom,
        dayOnly,
      );
      final weightByDay = <String, double>{
        for (final entry in weightLogs)
          entry.date.toParsedDay(): entry.weightKg,
      };
      final waistByDay = <String, double>{
        for (final entry in waistLogs) entry.date.toParsedDay(): entry.inches,
      };
      final weightSeries = sevenDayMovingAverage(
        from: rangeFrom,
        to: dayOnly,
        valuesByDay: weightByDay,
      );
      final waistSeries = sevenDayMovingAverage(
        from: rangeFrom,
        to: dayOnly,
        valuesByDay: waistByDay,
      );
      final weightAvg7dKg = weightSeries.isEmpty
          ? null
          : weightSeries.last.average7d;
      final waistAvg7dInches = waistSeries.isEmpty
          ? null
          : waistSeries.last.average7d;
      final waistInchesToday = waistByDay[dayOnly.toParsedDay()];

      final totalKcalLeft = CalorieGoalCalc.getDailyKcalLeft(
        totalKcalGoal,
        totalKcalIntake,
      );

      // #150: derive recommended per-meal kcal targets from the saved share.
      final breakfastKcalTarget = configData.targetKcalForMeal(
        ConfigEntity.mealKeyBreakfast,
        totalKcalGoal,
      );
      final lunchKcalTarget = configData.targetKcalForMeal(
        ConfigEntity.mealKeyLunch,
        totalKcalGoal,
      );
      final dinnerKcalTarget = configData.targetKcalForMeal(
        ConfigEntity.mealKeyDinner,
        totalKcalGoal,
      );
      final snackKcalTarget = configData.targetKcalForMeal(
        ConfigEntity.mealKeySnack,
        totalKcalGoal,
      );

      emit(
        HomeLoadedState(
          showDisclaimerDialog: showDisclaimerDialog,
          totalKcalDaily: totalKcalGoal,
          totalKcalLeft: totalKcalLeft,
          totalKcalSupplied: totalKcalIntake,
          totalKcalBurned: totalKcalActivities,
          totalCarbsIntake: totalCarbsIntake,
          totalFatsIntake: totalFatsIntake,
          totalCarbsGoal: totalCarbsGoal,
          totalFatsGoal: totalFatsGoal,
          totalProteinsGoal: totalProteinsGoal,
          totalProteinsIntake: totalProteinsIntake,
          breakfastIntakeList: breakfastIntakeList,
          lunchIntakeList: lunchIntakeList,
          dinnerIntakeList: dinnerIntakeList,
          snackIntakeList: snackIntakeList,
          userActivityList: userActivities,
          usesImperialUnits: usesImperialUnits,
          bodyWeightUnit: bodyWeightUnit,
          showActivityTracking: showActivityTracking,
          showMealMacros: showMealMacros,
          userWeightKg: user.weightKG,
          breakfastKcalTarget: breakfastKcalTarget,
          lunchKcalTarget: lunchKcalTarget,
          dinnerKcalTarget: dinnerKcalTarget,
          snackKcalTarget: snackKcalTarget,
          breakfastSharePct:
              configData.mealKcalSharesPct[ConfigEntity.mealKeyBreakfast] ?? 0,
          lunchSharePct:
              configData.mealKcalSharesPct[ConfigEntity.mealKeyLunch] ?? 0,
          dinnerSharePct:
              configData.mealKcalSharesPct[ConfigEntity.mealKeyDinner] ?? 0,
          snackSharePct:
              configData.mealKcalSharesPct[ConfigEntity.mealKeySnack] ?? 0,
          userGender: user.gender,
          userCaloriesProfile: user.caloriesProfile,
          waterMlToday: totalWaterMl,
          waterGoalMl: configData.effectiveDailyWaterGoalMl(
            user.gender,
            caloriesProfile: user.caloriesProfile,
          ),
          waterIntakes: waterIntakes,
          mealPlan: mealPlan,
          scheduledMacros: scheduledMacros,
          plannedKcal: plannedKcal,
          plannedProtein: plannedProtein,
          plannedFat: plannedFat,
          plannedCarbs: plannedCarbs,
          confirmedToDiaryCount: event.confirmedToDiaryCount,
          confirmedPlanFoodIntakeIds: confirmedPlanFoodIntakeIds,
          waistInchesToday: waistInchesToday,
          weightAvg7dKg: weightAvg7dKg,
          waistAvg7dInches: waistAvg7dInches,
        ),
      );
    });

    on<ConfirmMealPlanFoodEvent>((event, emit) async {
      final goals = await _confirmGoals();
      final count = await _confirmMealPlanToDiaryUsecase.confirmFood(
        food: event.food,
        meal: event.meal,
        day: currentDay,
        calorieGoal: goals.calorieGoal,
        carbsGoal: goals.carbsGoal,
        fatGoal: goals.fatGoal,
        proteinGoal: goals.proteinGoal,
      );
      await _updateDiaryPage(currentDay);
      add(LoadItemsEvent(confirmedToDiaryCount: count));
    });

    on<ConfirmMealPlanMealEvent>((event, emit) async {
      final goals = await _confirmGoals();
      final count = await _confirmMealPlanToDiaryUsecase.confirmMeal(
        meal: event.meal,
        day: currentDay,
        calorieGoal: goals.calorieGoal,
        carbsGoal: goals.carbsGoal,
        fatGoal: goals.fatGoal,
        proteinGoal: goals.proteinGoal,
      );
      await _updateDiaryPage(currentDay);
      add(LoadItemsEvent(confirmedToDiaryCount: count));
    });

    on<ConfirmMealPlanDayEvent>((event, emit) async {
      final planDate = currentDay.toParsedDay();
      final plan = await _getEffectiveMealPlanUsecase.execute(planDate);
      final goals = await _confirmGoals();
      final count = await _confirmMealPlanToDiaryUsecase.confirmPlan(
        plan: plan,
        day: currentDay,
        calorieGoal: goals.calorieGoal,
        carbsGoal: goals.carbsGoal,
        fatGoal: goals.fatGoal,
        proteinGoal: goals.proteinGoal,
      );
      await _updateDiaryPage(currentDay);
      add(LoadItemsEvent(confirmedToDiaryCount: count));
    });

    on<UnconfirmMealPlanFoodEvent>((event, emit) async {
      await _unconfirmMealPlanFoodUsecase.unconfirmFood(
        entryId: event.entryId,
        day: currentDay,
      );
      await _updateDiaryPage(currentDay);
      add(const LoadItemsEvent());
    });

    on<UnconfirmMealPlanMealEvent>((event, emit) async {
      await _unconfirmMealPlanFoodUsecase.unconfirmMeal(
        meal: event.meal,
        day: currentDay,
      );
      await _updateDiaryPage(currentDay);
      add(const LoadItemsEvent());
    });

    on<UpdateMealPlanMealMetaEvent>((event, emit) async {
      await _mutateDayMealPlan(
        (meals, entries) {
          final existing = meals.firstWhereOrNull(
            (m) => m.mealIndex == event.mealIndex,
          );
          final name = event.name.trim().isEmpty
              ? defaultMealName(event.mealIndex)
              : event.name.trim();
          final now = DateTime.now().toUtc();
          if (existing == null) {
            meals.add(
              DayMealEntity(
                id: _uuid.v4(),
                planDate: currentDay.toParsedDay(),
                mealIndex: event.mealIndex,
                name: name,
                mealTime: event.mealTime,
                updatedAt: now,
              ),
            );
          } else {
            final index = meals.indexOf(existing);
            meals[index] = DayMealEntity(
              id: existing.id,
              planDate: existing.planDate,
              mealIndex: existing.mealIndex,
              name: name,
              mealTime: event.mealTime,
              updatedAt: now,
            );
          }
        },
        ensureMealSlots: true,
        seedMealIndex: event.mealIndex,
        seedMealName: event.name,
        seedMealTime: event.mealTime,
      );
    });

    on<AddMealPlanMealSlotEvent>((event, emit) async {
      await _mutateDayMealPlan((meals, entries) {
        if (meals.length >= maxMealsPerDay) return;
        final index = meals.length;
        meals.add(
          DayMealEntity(
            id: _uuid.v4(),
            planDate: currentDay.toParsedDay(),
            mealIndex: index,
            name: defaultMealName(index),
            mealTime: null,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      });
    });

    on<RemoveMealPlanMealSlotEvent>((event, emit) async {
      await _mutateDayMealPlan((meals, entries) {
        if (meals.length <= minMealsPerDay) return;
        final meal = meals.firstWhereOrNull(
          (m) => m.mealIndex == event.mealIndex,
        );
        if (meal == null) return;
        entries.removeWhere((e) => e.dayMealId == meal.id);
        meals.removeWhere((m) => m.id == meal.id);
        meals.sort((a, b) => a.mealIndex.compareTo(b.mealIndex));
        final now = DateTime.now().toUtc();
        for (var i = 0; i < meals.length; i++) {
          final old = meals[i];
          meals[i] = DayMealEntity(
            id: old.id,
            planDate: old.planDate,
            mealIndex: i,
            name: old.name,
            mealTime: old.mealTime,
            updatedAt: now,
          );
        }
      });
    });

    on<UpdateMealPlanFoodQuantityEvent>((event, emit) async {
      await _mutateDayMealPlan((meals, entries) {
        final index = _findEntryIndex(
          meals: meals,
          entries: entries,
          mealIndex: event.mealIndex,
          entryId: event.entryId,
          foodId: event.foodId,
        );
        if (index < 0) return;
        final old = entries[index];
        entries[index] = MealPlanEntryEntity(
          id: old.id,
          planDate: old.planDate,
          dayMealId: old.dayMealId,
          foodId: old.foodId,
          foodName: old.foodName,
          brand: old.brand,
          caloriesPer100: old.caloriesPer100,
          proteinPer100: old.proteinPer100,
          fatPer100: old.fatPer100,
          carbsPer100: old.carbsPer100,
          quantity: event.quantity,
          unit: old.unit,
          updatedAt: DateTime.now().toUtc(),
        );
      });
    });

    on<DeleteMealPlanFoodEvent>((event, emit) async {
      await _mutateDayMealPlan((meals, entries) {
        final index = _findEntryIndex(
          meals: meals,
          entries: entries,
          mealIndex: event.mealIndex,
          entryId: event.entryId,
          foodId: event.foodId,
        );
        if (index < 0) return;
        entries.removeAt(index);
      });
    });

    on<AddMealPlanFoodEvent>((event, emit) async {
      await _mutateDayMealPlan(
        (meals, entries) {
          var meal = meals.firstWhereOrNull(
            (m) => m.mealIndex == event.mealIndex,
          );
          if (meal == null) {
            meal = DayMealEntity(
              id: event.mealId.isNotEmpty ? event.mealId : _uuid.v4(),
              planDate: currentDay.toParsedDay(),
              mealIndex: event.mealIndex,
              name: event.mealName.trim().isEmpty
                  ? defaultMealName(event.mealIndex)
                  : event.mealName.trim(),
              mealTime: event.mealTime,
              updatedAt: DateTime.now().toUtc(),
            );
            meals.add(meal);
          }
          entries.add(
            MealPlanEntryEntity(
              id: event.food.id.isNotEmpty ? event.food.id : _uuid.v4(),
              planDate: currentDay.toParsedDay(),
              dayMealId: meal.id,
              foodId: event.food.foodId,
              foodName: event.food.foodName,
              brand: event.food.brand,
              caloriesPer100: event.food.caloriesPer100,
              proteinPer100: event.food.proteinPer100,
              fatPer100: event.food.fatPer100,
              carbsPer100: event.food.carbsPer100,
              quantity: event.food.quantity,
              unit: event.food.unit,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
        },
        ensureMealSlots: true,
        seedMealIndex: event.mealIndex,
        seedMealName: event.mealName,
        seedMealTime: event.mealTime,
        seedMealId: event.mealId,
      );
    });
  }

  double getTotalKcal(List<IntakeEntity> intakeList) =>
      intakeList.map((intake) => intake.totalKcal).toList().sum;

  double getTotalCarbs(List<IntakeEntity> intakeList) =>
      intakeList.map((intake) => intake.totalCarbsGram).toList().sum;

  double getTotalFats(List<IntakeEntity> intakeList) =>
      intakeList.map((intake) => intake.totalFatsGram).toList().sum;

  double getTotalProteins(List<IntakeEntity> intakeList) =>
      intakeList.map((intake) => intake.totalProteinsGram).toList().sum;

  void saveConfigData(bool acceptedDisclaimer) async {
    _addConfigUsecase.setConfigDisclaimer(acceptedDisclaimer);
  }

  Future<void> updateIntakeItem(
    String intakeId,
    Map<String, dynamic> fields,
  ) async {
    final dateTime = await _currentLogicalDay();
    // Get old intake values
    final oldIntakeObject = await _getIntakeUsecase.getIntakeById(intakeId);
    if (oldIntakeObject == null) return;
    final newIntakeObject = await _updateIntakeUsecase.updateIntake(
      intakeId,
      fields,
    );
    if (newIntakeObject == null) return;
    if (oldIntakeObject.amount > newIntakeObject.amount) {
      // Amounts shrunk
      await _addTrackedDayUseCase.removeDayCaloriesTracked(
        dateTime,
        oldIntakeObject.totalKcal - newIntakeObject.totalKcal,
      );
      await _addTrackedDayUseCase.removeDayMacrosTracked(
        dateTime,
        carbsTracked:
            oldIntakeObject.totalCarbsGram - newIntakeObject.totalCarbsGram,
        fatTracked:
            oldIntakeObject.totalFatsGram - newIntakeObject.totalFatsGram,
        proteinTracked:
            oldIntakeObject.totalProteinsGram -
            newIntakeObject.totalProteinsGram,
      );
    } else if (newIntakeObject.amount > oldIntakeObject.amount) {
      // Amounts gained
      await _addTrackedDayUseCase.addDayCaloriesTracked(
        dateTime,
        newIntakeObject.totalKcal - oldIntakeObject.totalKcal,
      );
      await _addTrackedDayUseCase.addDayMacrosTracked(
        dateTime,
        carbsTracked:
            newIntakeObject.totalCarbsGram - oldIntakeObject.totalCarbsGram,
        fatTracked:
            newIntakeObject.totalFatsGram - oldIntakeObject.totalFatsGram,
        proteinTracked:
            newIntakeObject.totalProteinsGram -
            oldIntakeObject.totalProteinsGram,
      );
    }
    _updateDiaryPage(dateTime);
  }

  Future<void> deleteIntakeItem(IntakeEntity intakeEntity) async {
    final dateTime = await _currentLogicalDay();
    await _deleteIntakeUsecase.deleteIntake(intakeEntity);
    await _addTrackedDayUseCase.removeDayCaloriesTracked(
      dateTime,
      intakeEntity.totalKcal,
    );
    await _addTrackedDayUseCase.removeDayMacrosTracked(
      dateTime,
      carbsTracked: intakeEntity.totalCarbsGram,
      fatTracked: intakeEntity.totalFatsGram,
      proteinTracked: intakeEntity.totalProteinsGram,
    );

    _updateDiaryPage(dateTime);
  }

  Future<void> deleteUserActivityItem(UserActivityEntity activityEntity) async {
    final dateTime = await _currentLogicalDay();
    await _deleteUserActivityUsecase.deleteUserActivity(activityEntity);
    _addTrackedDayUseCase.reduceDayCalorieGoal(
      dateTime,
      activityEntity.burnedKcal,
    );

    final carbsAmount = MacroCalc.getTotalCarbsGoal(activityEntity.burnedKcal);
    final fatAmount = MacroCalc.getTotalFatsGoal(activityEntity.burnedKcal);
    final proteinAmount = MacroCalc.getTotalProteinsGoal(
      activityEntity.burnedKcal,
    );

    _addTrackedDayUseCase.reduceDayMacroGoals(
      dateTime,
      carbsAmount: carbsAmount,
      fatAmount: fatAmount,
      proteinAmount: proteinAmount,
    );
    _updateDiaryPage(dateTime);
    add(
      const LoadItemsEvent(),
    ); // #208: Reload home page to remove activity indicator
  }

  Future<void> updateUserActivityItem(
    UserActivityEntity activityEntity,
    double newDuration,
  ) async {
    final dateTime = await _currentLogicalDay();
    final newActivity = await _updateUserActivityUsecase.updateUserActivity(
      activityEntity,
      newDuration,
    );
    assert(newActivity != null);
    final kcalDiff = newActivity!.burnedKcal - activityEntity.burnedKcal;
    if (kcalDiff > 0) {
      _addTrackedDayUseCase.increaseDayCalorieGoal(dateTime, kcalDiff);
      _addTrackedDayUseCase.increaseDayMacroGoals(
        dateTime,
        carbsAmount: MacroCalc.getTotalCarbsGoal(kcalDiff),
        fatAmount: MacroCalc.getTotalFatsGoal(kcalDiff),
        proteinAmount: MacroCalc.getTotalProteinsGoal(kcalDiff),
      );
    } else if (kcalDiff < 0) {
      _addTrackedDayUseCase.reduceDayCalorieGoal(dateTime, kcalDiff.abs());
      _addTrackedDayUseCase.reduceDayMacroGoals(
        dateTime,
        carbsAmount: MacroCalc.getTotalCarbsGoal(kcalDiff.abs()),
        fatAmount: MacroCalc.getTotalFatsGoal(kcalDiff.abs()),
        proteinAmount: MacroCalc.getTotalProteinsGoal(kcalDiff.abs()),
      );
    }
    _updateDiaryPage(dateTime);
  }

  Future<void> _updateDiaryPage(DateTime day) async {
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
  }

  /// Logs a single water intake entry and reloads the home view so the
  /// chip updates immediately. The dialog itself only owns the slider
  /// value; persistence and recomputation flow back through the bloc.
  Future<void> addWaterIntake(int amountMl) async {
    if (amountMl <= 0) return;
    final entry = WaterIntakeEntity(
      id: 'water-${DateTime.now().microsecondsSinceEpoch}',
      dateTime: DateTime.now(),
      amountMl: amountMl,
    );
    await _addWaterIntakeUsecase.addEntry(entry);
    add(const LoadItemsEvent());
  }

  /// Rolls back the most recent water entry for the configured logical
  /// day. Returns whether anything was deleted, so the dialog can react
  /// without re-reading state.
  Future<bool> undoLastWaterIntake() async {
    final config = await _getConfigUsecase.getConfig();
    final entries = await _getWaterIntakeUsecase.getTodayEntries(
      dayStartOffsetTotalMinutes: config.dayStartOffsetTotalMinutes,
    );
    if (entries.isEmpty) return false;
    entries.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    await _deleteWaterIntakeUsecase.deleteEntry(entries.last.id);
    add(const LoadItemsEvent());
    return true;
  }

  /// #139: tracked-day deltas (calories, macros) must land on the
  /// user's logical "today" — for someone on a 04:30 boundary, a 02:00
  /// edit still updates yesterday's totals. We resolve the offset on
  /// each call so the most recent setting wins without needing the
  /// bloc to cache it explicitly. The follow-up to #139 reads the
  /// total-minutes value so the minute component (0-59) is honoured.
  Future<DateTime> _currentLogicalDay() async {
    final config = await _getConfigUsecase.getConfig();
    return DayBoundaryCalc.currentLogicalDayMinutes(
      config.dayStartOffsetTotalMinutes,
    );
  }

  Future<
    ({double calorieGoal, double carbsGoal, double fatGoal, double proteinGoal})
  >
  _confirmGoals() async {
    final planDate = currentDay.toParsedDay();
    final macros = await _getEffectiveMacroTargetUsecase.execute(planDate);
    if (macros.calories > 0) {
      return (
        calorieGoal: macros.calories.toDouble(),
        carbsGoal: macros.carbsG,
        fatGoal: macros.fatG,
        proteinGoal: macros.proteinG,
      );
    }
    final user = await _getUserUsecase.getUserData();
    final calorieGoal = await _getKcalGoalUsecase.getKcalGoal(userEntity: user);
    return (
      calorieGoal: calorieGoal,
      carbsGoal: await _getMacroGoalUsecase.getCarbsGoal(calorieGoal),
      fatGoal: await _getMacroGoalUsecase.getFatsGoal(calorieGoal),
      proteinGoal: await _getMacroGoalUsecase.getProteinsGoal(calorieGoal),
    );
  }

  /// Materializes a weekly template into a day override when needed, then
  /// applies [mutate] and persists via [SaveDayMealsUsecase] (same shape as
  /// DayMealPlanScreen._save).
  Future<void> _mutateDayMealPlan(
    void Function(List<DayMealEntity> meals, List<MealPlanEntryEntity> entries)
    mutate, {
    bool ensureMealSlots = false,
    int? seedMealIndex,
    String? seedMealName,
    String? seedMealTime,
    String? seedMealId,
  }) async {
    final planDate = currentDay.toParsedDay();
    final effective = await _getEffectiveMealPlanUsecase.execute(planDate);
    if (effective.source == MealPlanSource.weekly) {
      await _materializeWeeklyToDayUsecase.execute(planDate);
    }

    var meals = List<DayMealEntity>.from(
      await _getDayMealsUsecase.getMeals(planDate),
    );
    var entries = List<MealPlanEntryEntity>.from(
      await _getDayMealsUsecase.getEntries(planDate),
    );

    // Weekly with no rows, or an empty plan: seed day meals so edits stick.
    if (meals.isEmpty && (ensureMealSlots || effective.meals.isNotEmpty)) {
      final now = DateTime.now().toUtc();
      if (effective.meals.isNotEmpty &&
          effective.source != MealPlanSource.override) {
        // Copy effective (weekly) blocks into day entities — IDs refreshed.
        for (final block in effective.meals) {
          final mealId = _uuid.v4();
          meals.add(
            DayMealEntity(
              id: mealId,
              planDate: planDate,
              mealIndex: block.mealIndex,
              name: block.name,
              mealTime: block.mealTime,
              updatedAt: now,
            ),
          );
          for (final food in block.entries) {
            entries.add(
              MealPlanEntryEntity(
                id: _uuid.v4(),
                planDate: planDate,
                dayMealId: mealId,
                foodId: food.foodId,
                foodName: food.foodName,
                brand: food.brand,
                caloriesPer100: food.caloriesPer100,
                proteinPer100: food.proteinPer100,
                fatPer100: food.fatPer100,
                carbsPer100: food.carbsPer100,
                quantity: food.quantity,
                unit: food.unit,
                updatedAt: now,
              ),
            );
          }
        }
      } else if (ensureMealSlots && seedMealIndex != null) {
        meals.add(
          DayMealEntity(
            id: (seedMealId != null && seedMealId.isNotEmpty)
                ? seedMealId
                : _uuid.v4(),
            planDate: planDate,
            mealIndex: seedMealIndex,
            name: (seedMealName == null || seedMealName.trim().isEmpty)
                ? defaultMealName(seedMealIndex)
                : seedMealName.trim(),
            mealTime: seedMealTime,
            updatedAt: now,
          ),
        );
      }
    }

    mutate(meals, entries);

    await _saveDayMealsUsecase.saveDay(
      planDate: planDate,
      meals: meals,
      entries: entries,
    );
    await _updateDiaryPage(currentDay);
    add(const LoadItemsEvent());
  }

  int _findEntryIndex({
    required List<DayMealEntity> meals,
    required List<MealPlanEntryEntity> entries,
    required int mealIndex,
    required String entryId,
    required String foodId,
  }) {
    final byId = entries.indexWhere((e) => e.id == entryId);
    if (byId >= 0) return byId;

    final meal = meals.firstWhereOrNull((m) => m.mealIndex == mealIndex);
    if (meal == null) return -1;
    return entries.indexWhere(
      (e) => e.dayMealId == meal.id && e.foodId == foodId,
    );
  }
}
