import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/usecase/day_meals_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_effective_macro_target_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_effective_meal_plan_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/materialize_meal_plan_usecase.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_plan_utils.dart';
import 'package:opennutritracker/features/meal_plan/meal_plan_editor_widgets.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:uuid/uuid.dart';

class DayMealPlanScreen extends StatefulWidget {
  final DateTime day;

  const DayMealPlanScreen({super.key, required this.day});

  @override
  State<DayMealPlanScreen> createState() => _DayMealPlanScreenState();
}

class _DayMealPlanScreenState extends State<DayMealPlanScreen> {
  final _log = Logger('DayMealPlanScreen');
  static const _uuid = Uuid();

  bool _loading = true;
  bool _saving = false;
  bool _isOverride = false;
  List<EditableMealBlock> _meals = [];
  int? _targetCalories;
  double? _targetProtein;
  double? _targetFat;
  double? _targetCarbs;

  String get _planDate => widget.day.toParsedDay();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final plan = await locator<GetEffectiveMealPlanUsecase>().execute(
      _planDate,
    );
    final target = await locator<GetEffectiveMacroTargetUsecase>().execute(
      _planDate,
    );

    _isOverride = plan.source == MealPlanSource.override;
    if (plan.meals.isEmpty) {
      _meals = List.generate(
        defaultMealCount,
        (i) => EditableMealBlock(
          id: _uuid.v4(),
          mealIndex: i,
          name: defaultMealName(i),
        ),
      );
    } else {
      _meals = plan.meals
          .map(
            (m) => EditableMealBlock(
              id: m.id,
              mealIndex: m.mealIndex,
              name: m.name,
              mealTime: m.mealTime,
              entries: m.entries
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

    _targetCalories = target.calories;
    _targetProtein = target.proteinG;
    _targetFat = target.fatG;
    _targetCarbs = target.carbsG;

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _materialize() async {
    setState(() => _saving = true);
    try {
      await locator<MaterializeWeeklyToDayUsecase>().execute(_planDate);
      await _load();
    } catch (e, st) {
      _log.warning('Materialize failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _saving = true);
    try {
      await locator<ResetDayToWeeklyUsecase>().execute(_planDate);
      await _load();
    } catch (e, st) {
      _log.warning('Reset failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Editing always writes a day override.
      final now = DateTime.now().toUtc();
      final meals = <DayMealEntity>[];
      final entries = <MealPlanEntryEntity>[];
      for (final block in _meals) {
        final mealId = _isOverride ? block.id : _uuid.v4();
        meals.add(
          DayMealEntity(
            id: mealId,
            planDate: _planDate,
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
            MealPlanEntryEntity(
              id: _isOverride ? food.id : _uuid.v4(),
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
      await locator<SaveDayMealsUsecase>().saveDay(
        planDate: _planDate,
        meals: meals,
        entries: entries,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).calorieTrackerSyncSavedLabel)),
      );
    } catch (e, st) {
      _log.warning('Failed to save day meal plan', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleDate = DateFormat.yMMMEd().format(widget.day);
    return Scaffold(
      appBar: AppBar(
        title: Text('${S.of(context).dayMealPlanTitle} · $titleDate'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Dimens.spacing16),
              children: [
                Text(
                  _isOverride
                      ? 'Day override (customized for this date)'
                      : 'Showing weekly template for this weekday',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Dimens.spacing12),
                Wrap(
                  spacing: Dimens.spacing8,
                  runSpacing: Dimens.spacing8,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : _materialize,
                      child: Text(S.of(context).materializeWeeklyLabel),
                    ),
                    OutlinedButton(
                      onPressed: _saving || !_isOverride ? null : _reset,
                      child: Text(S.of(context).resetToWeeklyLabel),
                    ),
                  ],
                ),
                const SizedBox(height: Dimens.spacing16),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(S.of(context).saveWeeklyTargetsLabel),
                ),
              ],
            ),
    );
  }
}
