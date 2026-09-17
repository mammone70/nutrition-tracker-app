import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_plan/meal_plan_editor_widgets.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Home-centered view of today's effective meal plan: scheduled macros,
/// per-meal foods with confirm/delete, and shortcuts into the full editors.
class HomePlannedMealsWidget extends StatelessWidget {
  final HomeBloc homeBloc;
  final EffectiveMealPlan mealPlan;
  final EffectiveMacroTarget scheduledMacros;
  final double plannedKcal;
  final double plannedProtein;
  final double plannedFat;
  final double plannedCarbs;

  const HomePlannedMealsWidget({
    super.key,
    required this.homeBloc,
    required this.mealPlan,
    required this.scheduledMacros,
    required this.plannedKcal,
    required this.plannedProtein,
    required this.plannedFat,
    required this.plannedCarbs,
  });

  bool get _hasPlanFoods =>
      mealPlan.meals.any((meal) => meal.entries.isNotEmpty);

  void _openDayPlan(BuildContext context) {
    Navigator.of(context).pushNamed(
      NavigationOptions.dayMealPlanRoute,
      arguments: homeBloc.currentDay,
    );
  }

  void _openWeeklyPlans(BuildContext context) {
    Navigator.of(context).pushNamed(NavigationOptions.weeklyMealPlansRoute);
  }

  Future<void> _addFood(
    BuildContext context,
    EffectiveMealBlock meal,
  ) async {
    final food = await showAddMealPlanFoodDialog(context);
    if (food == null) return;
    homeBloc.add(
      AddMealPlanFoodEvent(
        mealIndex: meal.mealIndex,
        mealId: meal.id,
        mealName: meal.name,
        mealTime: meal.mealTime,
        food: MealPlanFoodEntry(
          id: food.id,
          foodId: food.foodId,
          foodName: food.foodName,
          brand: food.brand,
          caloriesPer100: food.caloriesPer100,
          proteinPer100: food.proteinPer100,
          fatPer100: food.fatPer100,
          carbsPer100: food.carbsPer100,
          quantity: food.quantity,
          unit: food.unit,
        ),
      ),
    );
  }

  Future<void> _editQuantity(
    BuildContext context,
    EffectiveMealBlock meal,
    MealPlanFoodEntry food,
  ) async {
    final controller = TextEditingController(
      text: food.quantity.toStringAsFixed(
        food.quantity == food.quantity.roundToDouble() ? 0 : 1,
      ),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(food.foodName),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: food.unit.isEmpty ? 'g' : food.unit,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(S.of(context).dialogCancelLabel),
            ),
            FilledButton(
              onPressed: () {
                final raw = controller.text.replaceAll(',', '.');
                final value = double.tryParse(raw);
                if (value == null || value <= 0) return;
                Navigator.of(context).pop(value);
              },
              child: Text(S.of(context).dialogOKLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    homeBloc.add(
      UpdateMealPlanFoodQuantityEvent(
        mealIndex: meal.mealIndex,
        entryId: food.id,
        foodId: food.foodId,
        quantity: result,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spacing16,
        Dimens.spacing12,
        Dimens.spacing16,
        Dimens.spacing4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.homePlannedMealsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Dimens.spacing8),
          if (scheduledMacros.calories > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: Dimens.spacing8),
              child: Text(
                '${s.homeScheduledMacrosLabel}: '
                '${scheduledMacros.calories} kcal · '
                'P ${scheduledMacros.proteinG.round()} · '
                'F ${scheduledMacros.fatG.round()} · '
                'C ${scheduledMacros.carbsG.round()}'
                '${_hasPlanFoods ? '  ·  '
                    'Σ ${plannedKcal.round()} / '
                    'P ${plannedProtein.round()} / '
                    'F ${plannedFat.round()} / '
                    'C ${plannedCarbs.round()}' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          if (!_hasPlanFoods) ...[
            Text(
              s.homePlannedEmptyHint,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Dimens.spacing8),
            Wrap(
              spacing: Dimens.spacing8,
              runSpacing: Dimens.spacing8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.restaurant_menu_outlined, size: 18),
                  label: Text(s.dayMealPlanTitle),
                  onPressed: () => _openDayPlan(context),
                ),
                ActionChip(
                  avatar: const Icon(Icons.restaurant_rounded, size: 18),
                  label: Text(s.settingsWeeklyMealPlansLabel),
                  onPressed: () => _openWeeklyPlans(context),
                ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: Dimens.spacing8,
              runSpacing: Dimens.spacing8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () =>
                      homeBloc.add(const ConfirmMealPlanDayEvent()),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: Text(s.homeConfirmAllPlannedLabel),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openDayPlan(context),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: Text(s.dayMealPlanTitle),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spacing12),
            ...mealPlan.meals.map((meal) {
              return Padding(
                padding: const EdgeInsets.only(bottom: Dimens.spacing12),
                child: AppCard(
                  padding: const EdgeInsets.all(Dimens.spacing12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              meal.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (meal.entries.isNotEmpty)
                            TextButton(
                              onPressed: () => homeBloc.add(
                                ConfirmMealPlanMealEvent(meal: meal),
                              ),
                              child: Text(s.homeConfirmMealLabel),
                            ),
                        ],
                      ),
                      if (meal.entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Dimens.spacing4,
                          ),
                          child: Text(
                            s.mealPlanEmptyLabel,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ...meal.entries.map((food) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(food.foodName),
                          subtitle: InkWell(
                            onTap: () => _editQuantity(context, meal, food),
                            child: Text(
                              '${food.quantity.toStringAsFixed(food.quantity == food.quantity.roundToDouble() ? 0 : 1)}'
                              ' ${food.unit.isEmpty ? 'g' : food.unit}'
                              ' · ${food.calories.round()} kcal'
                              ' · ${s.proteinLabelShort.toUpperCase()} ${food.proteinG.round()}'
                              ' · ${s.fatLabelShort.toUpperCase()} ${food.fatG.round()}'
                              ' · ${s.carbsLabelShort.toUpperCase()} ${food.carbsG.round()}',
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: s.homeConfirmFoodLabel,
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () => homeBloc.add(
                                  ConfirmMealPlanFoodEvent(
                                    food: food,
                                    meal: meal,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: s.itemDeletedSnackbar,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => homeBloc.add(
                                  DeleteMealPlanFoodEvent(
                                    mealIndex: meal.mealIndex,
                                    entryId: food.id,
                                    foodId: food.foodId,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _addFood(context, meal),
                          icon: const Icon(Icons.add),
                          label: Text(s.addMealPlanFoodLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
