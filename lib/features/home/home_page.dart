import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/empty_hint.dart';
import 'package:opennutritracker/core/presentation/widgets/low_kcal_warning_card.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/activity_vertial_list.dart';
import 'package:opennutritracker/core/presentation/widgets/edit_activity_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/edit_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/delete_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/disclaimer_dialog.dart';
import 'package:opennutritracker/core/domain/usecase/import_workouts_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/home/presentation/widgets/dashboard_widget.dart';
import 'package:opennutritracker/features/home/presentation/widgets/home_planned_meals_widget.dart';
import 'package:opennutritracker/features/home/presentation/widgets/intake_vertical_list.dart';
import 'package:opennutritracker/features/home/presentation/widgets/fasting_home_chip.dart';
import 'package:opennutritracker/features/home/presentation/widgets/quick_water_widget.dart';
import 'package:opennutritracker/features/home/presentation/widgets/quick_waist_widget.dart';
import 'package:opennutritracker/features/home/presentation/widgets/quick_weight_widget.dart';
import 'package:opennutritracker/features/trends/presentation/trends_page.dart';
import 'package:opennutritracker/generated/l10n.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final log = Logger('HomePage');

  late HomeBloc _homeBloc;
  bool _isIntakeDragging = false;
  bool _isActivityDragging = false;
  bool get _isDragging => _isIntakeDragging || _isActivityDragging;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _homeBloc = locator<HomeBloc>();
    // Workouts that landed in the health store while the app was closed. Run
    // from here rather than from bootstrap so a launch import reaches the
    // same diary refresh a resume import does.
    unawaited(_importHealthWorkouts());
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      bloc: _homeBloc,
      listenWhen: (previous, current) =>
          previous is HomeLoadingState &&
          current is HomeLoadedState &&
          current.confirmedToDiaryCount != null,
      listener: (context, state) {
        if (state is! HomeLoadedState) return;
        final count = state.confirmedToDiaryCount;
        if (count == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).homeConfirmedToDiarySnack(count)),
          ),
        );
      },
      builder: (context, state) {
        if (state is HomeInitial) {
          _homeBloc.add(const LoadItemsEvent());
          return _getLoadingContent();
        } else if (state is HomeLoadingState) {
          return _getLoadingContent();
        } else if (state is HomeLoadedState) {
          return _getLoadedContent(context, state);
        } else {
          return _getLoadingContent();
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      log.info('App resumed');
      _refreshPageOnDayChange();
      unawaited(_importHealthWorkouts());
    }
    super.didChangeAppLifecycleState(state);
  }

  Widget _getLoadingContent() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _getLoadedContent(BuildContext context, HomeLoadedState state) {
    final showDisclaimerDialog = state.showDisclaimerDialog;
    final totalKcalDaily = state.totalKcalDaily;
    final userGender = state.userGender;
    final userCaloriesProfile = state.userCaloriesProfile;
    final totalKcalLeft = state.totalKcalLeft;
    final totalKcalSupplied = state.totalKcalSupplied;
    final totalKcalBurned = state.totalKcalBurned;
    final totalCarbsIntake = state.totalCarbsIntake;
    final totalFatsIntake = state.totalFatsIntake;
    final totalProteinsIntake = state.totalProteinsIntake;
    final totalCarbsGoal = state.totalCarbsGoal;
    final totalFatsGoal = state.totalFatsGoal;
    final totalProteinsGoal = state.totalProteinsGoal;
    final breakfastIntakeList = state.breakfastIntakeList;
    final lunchIntakeList = state.lunchIntakeList;
    final dinnerIntakeList = state.dinnerIntakeList;
    final snackIntakeList = state.snackIntakeList;
    final userActivities = state.userActivityList;
    final usesImperialUnits = state.usesImperialUnits;
    final bodyWeightUnit = state.bodyWeightUnit;
    final showActivityTracking = state.showActivityTracking;
    final showMealMacros = state.showMealMacros;
    final userWeightKg = state.userWeightKg;
    final breakfastKcalTarget = state.breakfastKcalTarget;
    final lunchKcalTarget = state.lunchKcalTarget;
    final dinnerKcalTarget = state.dinnerKcalTarget;
    final snackKcalTarget = state.snackKcalTarget;
    final breakfastSharePct = state.breakfastSharePct;
    final lunchSharePct = state.lunchSharePct;
    final dinnerSharePct = state.dinnerSharePct;
    final snackSharePct = state.snackSharePct;
    final waterMlToday = state.waterMlToday;
    final waterGoalMl = state.waterGoalMl;

    if (showDisclaimerDialog) {
      _showDisclaimerDialog(context);
    }
    return Stack(
      children: [
        ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimens.spacing16,
                Dimens.spacing16,
                Dimens.spacing16,
                Dimens.spacing4,
              ),
              // Wrap rather than Row so the two chips drop onto a second line
              // at large text scale instead of overflowing off the edge.
              child: Wrap(
                spacing: Dimens.spacing12,
                runSpacing: Dimens.spacing8,
                children: [
                  QuickWeightWidget(
                    weightKg: userWeightKg,
                    bodyWeightUnit: bodyWeightUnit,
                    avg7dKg: state.weightAvg7dKg,
                  ),
                  QuickWaistWidget(
                    waistInches: state.waistInchesToday,
                    avg7dInches: state.waistAvg7dInches,
                  ),
                  QuickWaterWidget(
                    waterMlToday: waterMlToday,
                    waterGoalMl: waterGoalMl,
                  ),
                ],
              ),
            ),
            const FastingHomeChip(),
            const SizedBox(height: Dimens.spacing8),
            DashboardWidget(
              totalKcalDaily: totalKcalDaily,
              totalKcalLeft: totalKcalLeft,
              totalKcalSupplied: totalKcalSupplied,
              totalKcalBurned: totalKcalBurned,
              totalCarbsIntake: totalCarbsIntake,
              totalFatsIntake: totalFatsIntake,
              totalProteinsIntake: totalProteinsIntake,
              totalCarbsGoal: totalCarbsGoal,
              totalFatsGoal: totalFatsGoal,
              totalProteinsGoal: totalProteinsGoal,
            ),
            HomePlannedMealsWidget(
              homeBloc: _homeBloc,
              mealPlan: state.mealPlan,
              scheduledMacros: state.scheduledMacros,
              plannedKcal: state.plannedKcal,
              plannedProtein: state.plannedProtein,
              plannedFat: state.plannedFat,
              plannedCarbs: state.plannedCarbs,
              confirmedPlanFoodIntakeIds: state.confirmedPlanFoodIntakeIds,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimens.spacing16,
                Dimens.spacing4,
                Dimens.spacing16,
                Dimens.spacing4,
              ),
              child: Wrap(
                spacing: Dimens.spacing8,
                runSpacing: Dimens.spacing8,
                children: [
                  ActionChip(
                    key: const ValueKey('home-trends'),
                    avatar: const Icon(Icons.insights_outlined, size: 18),
                    label: Text(S.of(context).trendsLabel),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TrendsPage(),
                      ),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.calendar_view_week_rounded,
                      size: 18,
                    ),
                    label: Text(S.of(context).settingsWeeklyTargetsLabel),
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed(NavigationOptions.weeklyMacroTargetsRoute),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.restaurant_rounded, size: 18),
                    label: Text(S.of(context).settingsWeeklyMealPlansLabel),
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed(NavigationOptions.weeklyMealPlansRoute),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.restaurant_menu_outlined,
                      size: 18,
                    ),
                    label: Text(S.of(context).dayMealPlanTitle),
                    onPressed: () => Navigator.of(context).pushNamed(
                      NavigationOptions.dayMealPlanRoute,
                      arguments: _homeBloc.currentDay,
                    ),
                  ),
                ],
              ),
            ),
            // Day-one / empty-day guidance: when nothing is logged yet, point
            // the way to the centre + rather than leaving a silent dashboard.
            if (breakfastIntakeList.isEmpty &&
                lunchIntakeList.isEmpty &&
                dinnerIntakeList.isEmpty &&
                snackIntakeList.isEmpty &&
                userActivities.isEmpty)
              EmptyHint(
                icon: Icons.add_circle_outline_rounded,
                title: S.of(context).homeFirstMealHint,
              ),
            if (CalorieGoalCalc.isBelowRecommendedDailyKcalFloor(
              goalKcal: totalKcalDaily,
              gender: userGender,
              caloriesProfile: userCaloriesProfile,
            ))
              LowKcalWarningCard(
                thresholdKcal: CalorieGoalCalc.recommendedDailyKcalFloor(
                  gender: userGender,
                  caloriesProfile: userCaloriesProfile,
                ),
              ),
            if (showActivityTracking)
              ActivityVerticalList(
                day: DateTime.now(),
                title: S.of(context).activityLabel,
                userActivityList: userActivities,
                onItemLongPressedCallback: onActivityItemLongPressed,
                onItemTappedCallback: onActivityItemTapped,
                onItemDragCallback: onActivityItemDrag,
              ),
            // #150 follow-up: a 0% share (e.g. OMAD sets snack to 0) hides the
            // section entirely so the home view doesn't carry an empty header
            // the user explicitly opted out of. Already-logged intakes for a
            // hidden section still count toward daily totals.
            if (breakfastSharePct > 0)
              IntakeVerticalList(
                day: DateTime.now(),
                title: S.of(context).breakfastLabel,
                listIcon: IntakeTypeEntity.breakfast.getIconData(),
                addMealType: AddMealType.breakfastType,
                intakeList: breakfastIntakeList,
                onDeleteIntakeCallback: onDeleteIntake,
                onItemDragCallback: onIntakeItemDrag,
                onItemTappedCallback: onIntakeItemTapped,
                usesImperialUnits: usesImperialUnits,
                showMealMacros: showMealMacros,
                mealKcalTarget: breakfastKcalTarget,
              ),
            if (lunchSharePct > 0)
              IntakeVerticalList(
                day: DateTime.now(),
                title: S.of(context).lunchLabel,
                listIcon: IntakeTypeEntity.lunch.getIconData(),
                addMealType: AddMealType.lunchType,
                intakeList: lunchIntakeList,
                onDeleteIntakeCallback: onDeleteIntake,
                onItemDragCallback: onIntakeItemDrag,
                onItemTappedCallback: onIntakeItemTapped,
                usesImperialUnits: usesImperialUnits,
                showMealMacros: showMealMacros,
                mealKcalTarget: lunchKcalTarget,
              ),
            if (dinnerSharePct > 0)
              IntakeVerticalList(
                day: DateTime.now(),
                title: S.of(context).dinnerLabel,
                addMealType: AddMealType.dinnerType,
                listIcon: IntakeTypeEntity.dinner.getIconData(),
                intakeList: dinnerIntakeList,
                onDeleteIntakeCallback: onDeleteIntake,
                onItemDragCallback: onIntakeItemDrag,
                onItemTappedCallback: onIntakeItemTapped,
                usesImperialUnits: usesImperialUnits,
                showMealMacros: showMealMacros,
                mealKcalTarget: dinnerKcalTarget,
              ),
            if (snackSharePct > 0)
              IntakeVerticalList(
                day: DateTime.now(),
                title: S.of(context).snackLabel,
                listIcon: IntakeTypeEntity.snack.getIconData(),
                addMealType: AddMealType.snackType,
                intakeList: snackIntakeList,
                onDeleteIntakeCallback: onDeleteIntake,
                onItemDragCallback: onIntakeItemDrag,
                onItemTappedCallback: onIntakeItemTapped,
                usesImperialUnits: usesImperialUnits,
                showMealMacros: showMealMacros,
                mealKcalTarget: snackKcalTarget,
              ),
            const SizedBox(height: 48.0),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Visibility(
            visible: _isDragging,
            child: SizedBox(
              height: 70,
              child: Stack(
                children: [
                  DragTarget<IntakeEntity>(
                    onAcceptWithDetails: (data) {
                      _confirmDelete(context, data.data);
                    },
                    onLeave: (data) {
                      setState(() {
                        _isIntakeDragging = false;
                      });
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        margin: const EdgeInsets.fromLTRB(
                          Dimens.spacing16,
                          0,
                          Dimens.spacing16,
                          Dimens.spacing12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: Dimens.borderRadiusL,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.delete_rounded,
                            size: 32,
                            color: Theme.of(context).colorScheme.onError,
                          ),
                        ),
                      );
                    },
                  ),
                  DragTarget<UserActivityEntity>(
                    onAcceptWithDetails: (data) {
                      _confirmDeleteActivity(context, data.data);
                    },
                    onLeave: (data) {
                      setState(() {
                        _isActivityDragging = false;
                      });
                    },
                    builder: (context, candidateData, rejectedData) {
                      return const SizedBox.expand();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void onActivityItemLongPressed(
    BuildContext context,
    UserActivityEntity activityEntity,
  ) async {
    final deleteIntake = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteDialog(),
    );

    if (deleteIntake != null) {
      _homeBloc.deleteUserActivityItem(activityEntity);
      _homeBloc.add(const LoadItemsEvent());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).itemDeletedSnackbar)),
        );
      }
    }
  }

  void onIntakeItemLongPressed(
    BuildContext context,
    IntakeEntity intakeEntity,
  ) async {
    final deleteIntake = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteDialog(),
    );

    if (deleteIntake != null) {
      _homeBloc.deleteIntakeItem(intakeEntity);
      _homeBloc.add(const LoadItemsEvent());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).itemDeletedSnackbar)),
        );
      }
    }
  }

  void onIntakeItemDrag(bool isDragging) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isIntakeDragging = isDragging;
      });
    });
  }

  void onActivityItemDrag(bool isDragging) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isActivityDragging = isDragging;
      });
    });
  }

  void onActivityItemTapped(
    BuildContext context,
    UserActivityEntity activityEntity,
  ) async {
    final newDuration = await showDialog<double>(
      context: context,
      builder: (context) => EditActivityDialog(activityEntity: activityEntity),
    );
    if (newDuration != null) {
      await _homeBloc.updateUserActivityItem(activityEntity, newDuration);
      _homeBloc.add(const LoadItemsEvent());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).itemUpdatedSnackbar)),
        );
      }
    }
  }

  void onIntakeItemTapped(
    BuildContext context,
    IntakeEntity intakeEntity,
    bool usesImperialUnits,
  ) async {
    final changeIntakeAmount = await showDialog<double>(
      context: context,
      builder: (context) => EditDialog(
        intakeEntity: intakeEntity,
        usesImperialUnits: usesImperialUnits,
      ),
    );
    if (changeIntakeAmount != null) {
      _homeBloc.updateIntakeItem(intakeEntity.id, {
        'amount': changeIntakeAmount,
      });
      _homeBloc.add(const LoadItemsEvent());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).itemUpdatedSnackbar)),
        );
      }
    }
  }

  void onDeleteIntake(IntakeEntity intake, TrackedDayEntity? trackedDayEntity) {
    _homeBloc.deleteIntakeItem(intake);
    _homeBloc.add(const LoadItemsEvent());
  }

  void _confirmDelete(BuildContext context, IntakeEntity intake) async {
    bool? delete = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteDialog(),
    );

    if (delete == true) {
      onDeleteIntake(intake, null);
    }
    setState(() {
      _isIntakeDragging = false;
    });
  }

  void _confirmDeleteActivity(
    BuildContext context,
    UserActivityEntity activity,
  ) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteDialog(),
    );
    if (delete == true) {
      _homeBloc.deleteUserActivityItem(activity);
      _homeBloc.add(const LoadItemsEvent());
    }
    setState(() {
      _isActivityDragging = false;
    });
  }

  /// Show disclaimer dialog after build method
  void _showDisclaimerDialog(BuildContext context) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final dialogConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return const DisclaimerDialog();
        },
      );
      if (dialogConfirmed != null) {
        _homeBloc.saveConfigData(dialogConfirmed);
        _homeBloc.add(const LoadItemsEvent());
      }
    });
  }

  /// Refresh page when day changes
  ///
  /// #139: HomeBloc.currentDay is the logical "today" (midnight of the
  /// configured day boundary). Comparing against a fresh logical "today"
  /// from the same wall clock requires knowing the offset, which we'd
  /// have to fetch from config asynchronously. Letting LoadItemsEvent
  /// re-resolve the offset and reload unconditionally on resume is the
  /// honest cheap path: it costs one config read plus a few Hive scans,
  /// and it is correct under any boundary setting.
  void _refreshPageOnDayChange() {
    _homeBloc.add(const LoadItemsEvent());
  }

  /// Picks up workouts that landed in the platform health store while the app
  /// was away — at launch and on every resume. Debounced, serialized and
  /// opt-in inside the use case, so this costs nothing on an ordinary resume;
  /// the diary only reloads when something actually came in. Failures are
  /// swallowed by [ImportWorkoutsUsecase.importIfDue]: there is no user
  /// waiting on this and nowhere to show an error.
  Future<void> _importHealthWorkouts() async {
    final imported = await locator<ImportWorkoutsUsecase>().importIfDue();
    if (imported == 0 || !mounted) return;
    _homeBloc.add(const LoadItemsEvent());
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
  }
}
