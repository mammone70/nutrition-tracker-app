import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/usecase/weekly_macro_target_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/weekly_meals_usecase.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_plan_utils.dart';
import 'package:opennutritracker/features/meal_plan/meal_plan_editor_widgets.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:uuid/uuid.dart';

class WeeklyMealPlansScreen extends StatefulWidget {
  const WeeklyMealPlansScreen({super.key});

  @override
  State<WeeklyMealPlansScreen> createState() => _WeeklyMealPlansScreenState();
}

class _WeeklyMealPlansScreenState extends State<WeeklyMealPlansScreen> {
  final _log = Logger('WeeklyMealPlansScreen');
  static const _uuid = Uuid();

  int _selectedDay = 0;
  bool _loading = true;
  bool _saving = false;
  List<EditableMealBlock> _meals = [];
  int? _targetCalories;
  double? _targetProtein;
  double? _targetFat;
  double? _targetCarbs;

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  Future<void> _loadDay() async {
    setState(() => _loading = true);
    final getMeals = locator<GetWeeklyMealsUsecase>();
    final meals = await getMeals.getMealsByDay(_selectedDay);
    final entries = await getMeals.getEntriesForMeals(meals);
    final weeklyTarget = await locator<GetWeeklyMacroTargetsUsecase>()
        .getByDayOfWeek(_selectedDay);

    if (meals.isEmpty) {
      _meals = List.generate(
        defaultMealCount,
        (i) => EditableMealBlock(
          id: _uuid.v4(),
          mealIndex: i,
          name: defaultMealName(i),
        ),
      );
    } else {
      _meals = meals
          .map(
            (m) => EditableMealBlock(
              id: m.id,
              mealIndex: m.mealIndex,
              name: m.name,
              mealTime: m.mealTime,
              entries: entries
                  .where((e) => e.weeklyMealId == m.id)
                  .map(
                    (e) => EditableMealPlanFood(
                      id: e.id,
                      foodId: e.foodId,
                      foodName: e.foodName,
                      brand: e.brand,
                      caloriesPer100: e.caloriesPer100,
                      proteinPer100: e.proteinPer100,
                      fatPer100: e.fatPer100,
                      carbsPer100: e.carbsPer100,
                      quantity: e.quantity,
                      unit: e.unit,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList();
    }

    _targetCalories = weeklyTarget?.calories;
    _targetProtein = weeklyTarget?.proteinG;
    _targetFat = weeklyTarget?.fatG;
    _targetCarbs = weeklyTarget?.carbsG;

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final now = DateTime.now().toUtc();
      final meals = <WeeklyMealEntity>[];
      final entries = <WeeklyMealPlanEntryEntity>[];
      for (final block in _meals) {
        meals.add(
          WeeklyMealEntity(
            id: block.id,
            dayOfWeek: _selectedDay,
            mealIndex: block.mealIndex,
            name: block.name.trim().isEmpty
                ? defaultMealName(block.mealIndex)
                : block.name.trim(),
            mealTime: block.mealTime,
            updatedAt: now,
          ),
        );
        for (final food in block.entries) {
          entries.add(
            WeeklyMealPlanEntryEntity(
              id: food.id,
              weeklyMealId: block.id,
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
      await locator<SaveWeeklyMealsUsecase>().saveDay(
        dayOfWeek: _selectedDay,
        meals: meals,
        entries: entries,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).calorieTrackerSyncSavedLabel)),
      );
    } catch (e, st) {
      _log.warning('Failed to save weekly meal plan', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _weekdayLabel(int index) {
    switch (index) {
      case 0:
        return S.of(context).weekdayMonday;
      case 1:
        return S.of(context).weekdayTuesday;
      case 2:
        return S.of(context).weekdayWednesday;
      case 3:
        return S.of(context).weekdayThursday;
      case 4:
        return S.of(context).weekdayFriday;
      case 5:
        return S.of(context).weekdaySaturday;
      default:
        return S.of(context).weekdaySunday;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).weeklyMealPlansTitle)),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Dimens.spacing12),
              itemCount: 7,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: Dimens.spacing8),
              itemBuilder: (context, index) {
                return ChoiceChip(
                  label: Text(_weekdayLabel(index)),
                  selected: _selectedDay == index,
                  onSelected: (_) {
                    setState(() => _selectedDay = index);
                    _loadDay();
                  },
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(Dimens.spacing16),
                    children: [
                      Text(
                        S.of(context).weeklyMealPlansSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: Dimens.spacing12),
                      buildMealBlocksEditor(
                        context: context,
                        meals: _meals,
                        onChanged: () => setState(() {}),
                        onAddFood: () async {},
                        targetCalories: _targetCalories,
                        targetProtein: _targetProtein,
                        targetFat: _targetFat,
                        targetCarbs: _targetCarbs,
                      ),
                      const SizedBox(height: Dimens.spacing16),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(S.of(context).saveWeeklyTargetsLabel),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
