import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/usecase/day_meals_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_effective_meal_plan_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/materialize_meal_plan_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_plan_utils.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:uuid/uuid.dart';

/// Compact day-override meal structure editor for the diary day view.
/// Edits meal count / name / time only (foods stay on the day plan screen).
class DiaryDayMealsEditor extends StatefulWidget {
  final DateTime day;
  final ValueChanged<List<DayMealEntity>>? onMealsChanged;

  const DiaryDayMealsEditor({
    super.key,
    required this.day,
    this.onMealsChanged,
  });

  @override
  State<DiaryDayMealsEditor> createState() => _DiaryDayMealsEditorState();
}

class _DiaryDayMealsEditorState extends State<DiaryDayMealsEditor> {
  static const _uuid = Uuid();

  bool _loading = true;
  bool _saving = false;
  List<DayMealEntity> _meals = [];
  List<MealPlanEntryEntity> _entries = [];

  String get _planDate => widget.day.toParsedDay();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DiaryDayMealsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.day, widget.day)) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final plan = await locator<GetEffectiveMealPlanUsecase>().execute(
      _planDate,
    );
    var meals = await locator<GetDayMealsUsecase>().getMeals(_planDate);
    var entries = await locator<GetDayMealsUsecase>().getEntries(_planDate);

    if (meals.isEmpty && plan.meals.isNotEmpty) {
      meals = plan.meals
          .map(
            (m) => DayMealEntity(
              id: m.id,
              planDate: _planDate,
              mealIndex: m.mealIndex,
              name: m.name,
              mealTime: m.mealTime,
              updatedAt: DateTime.now().toUtc(),
            ),
          )
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _meals = List.of(meals)
        ..sort((a, b) => a.mealIndex.compareTo(b.mealIndex));
      _entries = List.of(entries);
      _loading = false;
    });
    widget.onMealsChanged?.call(_meals);
  }

  Future<void> _ensureDayOverride() async {
    final plan = await locator<GetEffectiveMealPlanUsecase>().execute(
      _planDate,
    );
    if (plan.source == MealPlanSource.weekly) {
      await locator<MaterializeWeeklyToDayUsecase>().execute(_planDate);
      _meals = await locator<GetDayMealsUsecase>().getMeals(_planDate);
      _entries = await locator<GetDayMealsUsecase>().getEntries(_planDate);
      if (_meals.isEmpty && plan.meals.isNotEmpty) {
        final now = DateTime.now().toUtc();
        _meals = [];
        _entries = [];
        for (final block in plan.meals) {
          final mealId = _uuid.v4();
          _meals.add(
            DayMealEntity(
              id: mealId,
              planDate: _planDate,
              mealIndex: block.mealIndex,
              name: block.name,
              mealTime: block.mealTime,
              updatedAt: now,
            ),
          );
          for (final food in block.entries) {
            _entries.add(
              MealPlanEntryEntity(
                id: _uuid.v4(),
                planDate: _planDate,
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
      }
    }
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    try {
      await _ensureDayOverride();
      await locator<SaveDayMealsUsecase>().saveDay(
        planDate: _planDate,
        meals: _meals,
        entries: _entries,
      );
      widget.onMealsChanged?.call(_meals);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).calorieTrackerSyncSavedLabel)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addMeal() {
    if (_meals.length >= maxMealsPerDay) return;
    setState(() {
      final index = _meals.length;
      _meals.add(
        DayMealEntity(
          id: _uuid.v4(),
          planDate: _planDate,
          mealIndex: index,
          name: defaultMealName(index),
          mealTime: null,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    });
  }

  void _removeLastMeal() {
    if (_meals.length <= minMealsPerDay) return;
    setState(() {
      final removed = _meals.removeLast();
      _entries.removeWhere((e) => e.dayMealId == removed.id);
      for (var i = 0; i < _meals.length; i++) {
        final old = _meals[i];
        _meals[i] = DayMealEntity(
          id: old.id,
          planDate: old.planDate,
          mealIndex: i,
          name: old.name,
          mealTime: old.mealTime,
          updatedAt: DateTime.now().toUtc(),
        );
      }
    });
  }

  void _updateMeal(
    int index, {
    String? name,
    String? mealTime,
    bool clearTime = false,
  }) {
    final old = _meals[index];
    setState(() {
      _meals[index] = DayMealEntity(
        id: old.id,
        planDate: old.planDate,
        mealIndex: old.mealIndex,
        name: name ?? old.name,
        mealTime: clearTime ? null : (mealTime ?? old.mealTime),
        updatedAt: DateTime.now().toUtc(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(Dimens.spacing16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spacing16,
        Dimens.spacing8,
        Dimens.spacing16,
        Dimens.spacing8,
      ),
      child: AppCard(
        padding: const EdgeInsets.all(Dimens.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.dayMealPlanTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving || _meals.length <= minMealsPerDay
                      ? null
                      : _removeLastMeal,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  onPressed: _saving || _meals.length >= maxMealsPerDay
                      ? null
                      : _addMeal,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (_meals.isEmpty)
              Text(
                s.mealPlanEmptyLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ...List.generate(_meals.length, (index) {
              final meal = _meals[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: Dimens.spacing8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        key: ValueKey('diary-meal-name-${meal.id}'),
                        initialValue: meal.name,
                        decoration: InputDecoration(
                          labelText: s.mealNameLabel,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => _updateMeal(index, name: v),
                      ),
                    ),
                    const SizedBox(width: Dimens.spacing8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: ValueKey('diary-meal-time-${meal.id}'),
                        initialValue: meal.mealTime ?? '',
                        decoration: InputDecoration(
                          labelText: s.mealTimeShortLabel,
                          hintText: 'HH:MM',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          final trimmed = v.trim();
                          if (trimmed.isEmpty) {
                            _updateMeal(index, clearTime: true);
                          } else {
                            _updateMeal(index, mealTime: trimmed);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _saving ? null : _persist,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.saveWeeklyTargetsLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
