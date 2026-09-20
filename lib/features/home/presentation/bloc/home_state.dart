part of 'home_bloc.dart';

abstract class HomeState extends Equatable {
  const HomeState();
}

class HomeInitial extends HomeState {
  @override
  List<Object> get props => [];
}

class HomeLoadingState extends HomeState {
  @override
  List<Object?> get props => [];
}

class HomeLoadedState extends HomeState {
  final bool showDisclaimerDialog;
  final double totalKcalDaily;
  final double totalKcalLeft;
  final double totalKcalSupplied;
  final double totalKcalBurned;
  final double totalCarbsIntake;
  final double totalFatsIntake;
  final double totalProteinsIntake;
  final double totalCarbsGoal;
  final double totalFatsGoal;
  final double totalProteinsGoal;
  final List<UserActivityEntity> userActivityList;
  final List<IntakeEntity> breakfastIntakeList;
  final List<IntakeEntity> lunchIntakeList;
  final List<IntakeEntity> dinnerIntakeList;
  final List<IntakeEntity> snackIntakeList;
  // Food serving units (g/oz). Sourced from the food-units preference.
  final bool usesImperialUnits;
  // Body weight unit (kg/lb/st) for the home weight chip, independent of food.
  final BodyWeightUnit bodyWeightUnit;
  final bool showActivityTracking; // #277
  final bool showMealMacros;
  final double userWeightKg;
  // #150: recommended kcal target for each meal section, derived from the
  // daily goal and the share configured under Settings → Calculations.
  final double breakfastKcalTarget;
  final double lunchKcalTarget;
  final double dinnerKcalTarget;
  final double snackKcalTarget;
  // #150 follow-up: per-meal share percentages. A 0% share signals that the
  // user has explicitly opted out of seeing that meal section (e.g. OMAD has
  // 0% snack), so the section is hidden entirely rather than showing an empty
  // header with a 0-kcal target.
  final int breakfastSharePct;
  final int lunchSharePct;
  final int dinnerSharePct;
  final int snackSharePct;
  final UserGenderEntity userGender;
  final CaloriesProfileEntity? userCaloriesProfile;
  // #32: hydration totals for the home chip. waterMlToday is summed across
  // every entry that falls within the configured logical day; waterGoalMl
  // is the user-configurable target (Settings → Calculations).
  final int waterMlToday;
  final int waterGoalMl;
  final List<WaterIntakeEntity> waterIntakes;
  final EffectiveMealPlan mealPlan;
  final EffectiveMacroTarget scheduledMacros;
  final double plannedKcal;
  final double plannedProtein;
  final double plannedFat;
  final double plannedCarbs;

  /// Set after a confirm-to-diary action so the UI can show a snack; null
  /// on ordinary reloads.
  final int? confirmedToDiaryCount;

  /// plan-entry id → diary intake id for foods confirmed today.
  final Map<String, String> confirmedPlanFoodIntakeIds;
  final double? waistInchesToday;
  final double? weightAvg7dKg;
  final double? waistAvg7dInches;

  const HomeLoadedState({
    required this.showDisclaimerDialog,
    required this.totalKcalDaily,
    required this.totalKcalLeft,
    required this.totalKcalSupplied,
    required this.totalKcalBurned,
    required this.totalCarbsIntake,
    required this.totalFatsIntake,
    required this.totalProteinsIntake,
    required this.totalCarbsGoal,
    required this.totalFatsGoal,
    required this.totalProteinsGoal,
    required this.userActivityList,
    required this.breakfastIntakeList,
    required this.lunchIntakeList,
    required this.dinnerIntakeList,
    required this.snackIntakeList,
    required this.usesImperialUnits,
    required this.bodyWeightUnit,
    required this.userWeightKg,
    required this.breakfastKcalTarget,
    required this.lunchKcalTarget,
    required this.dinnerKcalTarget,
    required this.snackKcalTarget,
    required this.breakfastSharePct,
    required this.lunchSharePct,
    required this.dinnerSharePct,
    required this.snackSharePct,
    required this.userGender,
    required this.userCaloriesProfile,
    required this.waterMlToday,
    required this.waterGoalMl,
    required this.waterIntakes,
    required this.mealPlan,
    required this.scheduledMacros,
    required this.plannedKcal,
    required this.plannedProtein,
    required this.plannedFat,
    required this.plannedCarbs,
    this.confirmedToDiaryCount,
    this.confirmedPlanFoodIntakeIds = const {},
    this.waistInchesToday,
    this.weightAvg7dKg,
    this.waistAvg7dInches,
    this.showActivityTracking = true,
    this.showMealMacros = true,
  });

  @override
  List<Object?> get props => [
    breakfastIntakeList,
    lunchIntakeList,
    dinnerIntakeList,
    snackIntakeList,
    usesImperialUnits,
    bodyWeightUnit,
    userWeightKg,
    totalKcalDaily,
    waterMlToday,
    waterGoalMl,
    waterIntakes,
    showActivityTracking,
    mealPlan,
    scheduledMacros,
    plannedKcal,
    plannedProtein,
    plannedFat,
    plannedCarbs,
    confirmedToDiaryCount,
    confirmedPlanFoodIntakeIds,
    waistInchesToday,
    weightAvg7dKg,
    waistAvg7dInches,
  ];
}
