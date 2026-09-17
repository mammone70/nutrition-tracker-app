import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/usecase/ensure_custom_meal_for_plan_food.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_sync_mapper.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_plan_utils.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:uuid/uuid.dart';

class EditableMealPlanFood {
  final String id;
  String foodId;
  String foodName;
  String? brand;
  double caloriesPer100;
  double proteinPer100;
  double fatPer100;
  double carbsPer100;
  double quantity;
  String unit;

  EditableMealPlanFood({
    required this.id,
    required this.foodId,
    required this.foodName,
    this.brand,
    required this.caloriesPer100,
    required this.proteinPer100,
    required this.fatPer100,
    required this.carbsPer100,
    required this.quantity,
    this.unit = 'g',
  });

  double get calories => caloriesPer100 * quantity / 100;
  double get proteinG => proteinPer100 * quantity / 100;
  double get fatG => fatPer100 * quantity / 100;
  double get carbsG => carbsPer100 * quantity / 100;
}

class EditableMealBlock {
  String id;
  int mealIndex;
  String name;
  String? mealTime;
  List<EditableMealPlanFood> entries;

  EditableMealBlock({
    required this.id,
    required this.mealIndex,
    required this.name,
    this.mealTime,
    List<EditableMealPlanFood>? entries,
  }) : entries = entries ?? [];

  double get calories => entries.fold(0.0, (sum, e) => sum + e.calories);
  double get proteinG => entries.fold(0.0, (sum, e) => sum + e.proteinG);
  double get fatG => entries.fold(0.0, (sum, e) => sum + e.fatG);
  double get carbsG => entries.fold(0.0, (sum, e) => sum + e.carbsG);
}

Future<EditableMealPlanFood?> showAddMealPlanFoodDialog(
  BuildContext context,
) async {
  return showModalBottomSheet<EditableMealPlanFood>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _AddMealPlanFoodSheet(),
  );
}

class _AddMealPlanFoodSheet extends StatefulWidget {
  const _AddMealPlanFoodSheet();

  @override
  State<_AddMealPlanFoodSheet> createState() => _AddMealPlanFoodSheetState();
}

class _AddMealPlanFoodSheetState extends State<_AddMealPlanFoodSheet> {
  static const _uuid = Uuid();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _calController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbsController = TextEditingController();
  final _qtyController = TextEditingController(text: '100');
  List<MealDBO> _customMeals = [];

  @override
  void initState() {
    super.initState();
    _customMeals = locator<HiveDBProvider>().customMealBox.values.toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _calController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _pickCustom(MealDBO meal) {
    final entity = MealEntity.fromMealDBO(meal);
    final foodId = CalorieTrackerSyncMapper.foodIdForMeal(entity);
    final n = meal.nutriments;
    final qty = double.tryParse(_qtyController.text) ?? 100;
    Navigator.of(context).pop(
      EditableMealPlanFood(
        id: _uuid.v4(),
        foodId: foodId,
        foodName: meal.name ?? 'Food',
        brand: meal.brands,
        caloriesPer100: n.energyKcal100 ?? 0,
        proteinPer100: n.proteins100 ?? 0,
        fatPer100: n.fat100 ?? 0,
        carbsPer100: n.carbohydrates100 ?? 0,
        quantity: qty,
      ),
    );
  }

  Future<void> _submitManual() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final cal = double.tryParse(_calController.text) ?? 0;
    final protein = double.tryParse(_proteinController.text) ?? 0;
    final fat = double.tryParse(_fatController.text) ?? 0;
    final carbs = double.tryParse(_carbsController.text) ?? 0;
    final qty = double.tryParse(_qtyController.text) ?? 100;
    final brand = _brandController.text.trim();
    final foodId = CalorieTrackerSyncMapper.foodIdForManual(
      name: name,
      brand: brand.isEmpty ? null : brand,
      caloriesPer100: cal,
      proteinPer100: protein,
      fatPer100: fat,
      carbsPer100: carbs,
    );
    final food = EditableMealPlanFood(
      id: _uuid.v4(),
      foodId: foodId,
      foodName: name,
      brand: brand.isEmpty ? null : brand,
      caloriesPer100: cal,
      proteinPer100: protein,
      fatPer100: fat,
      carbsPer100: carbs,
      quantity: qty,
    );
    await ensureCustomMealForPlanFood(
      customMeals: locator<CustomMealDataSource>(),
      name: food.foodName,
      brand: food.brand,
      caloriesPer100: food.caloriesPer100,
      proteinPer100: food.proteinPer100,
      fatPer100: food.fatPer100,
      carbsPer100: food.carbsPer100,
      unit: food.unit,
      preferredCode: food.foodId,
    );
    if (!mounted) return;
    Navigator.of(context).pop(food);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Dimens.spacing16,
        0,
        Dimens.spacing16,
        bottom + Dimens.spacing16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.of(context).addMealPlanFoodLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Dimens.spacing12),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity (g)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_customMeals.isNotEmpty) ...[
              const SizedBox(height: Dimens.spacing12),
              Text(
                'Custom meals',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: Dimens.spacing8),
              ..._customMeals
                  .take(20)
                  .map(
                    (meal) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(meal.name ?? 'Food'),
                      subtitle: meal.brands == null ? null : Text(meal.brands!),
                      onTap: () => _pickCustom(meal),
                    ),
                  ),
              const Divider(),
            ],
            Text(
              'Or enter manually',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: Dimens.spacing8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Dimens.spacing8),
            TextField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: 'Brand (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Dimens.spacing8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _calController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'kcal/100g',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: Dimens.spacing8),
                Expanded(
                  child: TextField(
                    controller: _proteinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'P/100g',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spacing8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fatController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'F/100g',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: Dimens.spacing8),
                Expanded(
                  child: TextField(
                    controller: _carbsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'C/100g',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spacing16),
            FilledButton(
              onPressed: _submitManual,
              child: Text(S.of(context).addMealPlanFoodLabel),
            ),
          ],
        ),
      ),
    );
  }
}

Widget buildMealBlocksEditor({
  required BuildContext context,
  required List<EditableMealBlock> meals,
  required VoidCallback onChanged,
  required Future<void> Function() onAddFood,
  int? targetCalories,
  double? targetProtein,
  double? targetFat,
  double? targetCarbs,
}) {
  final plannedCal = meals.fold(0.0, (s, m) => s + m.calories);
  final plannedP = meals.fold(0.0, (s, m) => s + m.proteinG);
  final plannedF = meals.fold(0.0, (s, m) => s + m.fatG);
  final plannedC = meals.fold(0.0, (s, m) => s + m.carbsG);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (targetCalories != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Dimens.spacing12),
          child: Text(
            'Planned ${plannedCal.round()} / $targetCalories kcal · '
            'P ${plannedP.round()}/${targetProtein?.round() ?? 0} · '
            'F ${plannedF.round()}/${targetFat?.round() ?? 0} · '
            'C ${plannedC.round()}/${targetCarbs?.round() ?? 0}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      Row(
        children: [
          Text(
            'Meals: ${meals.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          IconButton(
            onPressed: meals.length <= minMealsPerDay
                ? null
                : () {
                    meals.removeLast();
                    for (var i = 0; i < meals.length; i++) {
                      meals[i].mealIndex = i;
                    }
                    onChanged();
                  },
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            onPressed: meals.length >= maxMealsPerDay
                ? null
                : () {
                    meals.add(
                      EditableMealBlock(
                        id: const Uuid().v4(),
                        mealIndex: meals.length,
                        name: defaultMealName(meals.length),
                      ),
                    );
                    onChanged();
                  },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      if (meals.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimens.spacing24),
          child: Text(
            S.of(context).mealPlanEmptyLabel,
            textAlign: TextAlign.center,
          ),
        ),
      ...meals.map((meal) {
        return Card(
          margin: const EdgeInsets.only(bottom: Dimens.spacing12),
          child: Padding(
            padding: const EdgeInsets.all(Dimens.spacing12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: meal.name,
                  decoration: const InputDecoration(
                    labelText: 'Meal name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    meal.name = v;
                    onChanged();
                  },
                ),
                const SizedBox(height: Dimens.spacing8),
                TextFormField(
                  initialValue: meal.mealTime ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Time (HH:MM, optional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    meal.mealTime = v.trim().isEmpty ? null : v.trim();
                    onChanged();
                  },
                ),
                const SizedBox(height: Dimens.spacing8),
                ...meal.entries.map((entry) {
                  final s = S.of(context);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.foodName),
                    subtitle: Text(
                      '${entry.quantity.toStringAsFixed(0)} ${entry.unit} · '
                      '${entry.calories.round()} kcal · '
                      '${s.proteinLabelShort.toUpperCase()} ${entry.proteinG.round()} · '
                      '${s.fatLabelShort.toUpperCase()} ${entry.fatG.round()} · '
                      '${s.carbsLabelShort.toUpperCase()} ${entry.carbsG.round()}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        meal.entries.remove(entry);
                        onChanged();
                      },
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () async {
                    final food = await showAddMealPlanFoodDialog(context);
                    if (food != null) {
                      meal.entries.add(food);
                      onChanged();
                    }
                    await onAddFood();
                  },
                  icon: const Icon(Icons.add),
                  label: Text(S.of(context).addMealPlanFoodLabel),
                ),
              ],
            ),
          ),
        );
      }),
    ],
  );
}
