import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

/// Saves a meal-plan food into the user's custom food DB when nothing there
/// already matches by name (and brand, when provided).
///
/// Matching is case-insensitive on name. When [brand] is non-empty, brand must
/// also match; when brand is empty/null, any custom meal with that name counts.
///
/// Returns `true` when a new custom meal was written.
Future<bool> ensureCustomMealForPlanFood({
  required CustomMealDataSource customMeals,
  required String name,
  String? brand,
  required double caloriesPer100,
  required double proteinPer100,
  required double fatPer100,
  required double carbsPer100,
  String unit = 'g',
  String? preferredCode,
}) async {
  final trimmedName = name.trim();
  if (trimmedName.isEmpty) return false;

  final trimmedBrand = brand?.trim();
  final alreadyExists = customMeals.getAllCustomMeals().any((meal) {
    final mealName = (meal.name ?? '').trim().toLowerCase();
    if (mealName != trimmedName.toLowerCase()) return false;
    if (trimmedBrand == null || trimmedBrand.isEmpty) return true;
    return (meal.brands ?? '').trim() == trimmedBrand;
  });
  if (alreadyExists) return false;

  final entity = MealEntity(
    code: (preferredCode != null && preferredCode.isNotEmpty)
        ? preferredCode
        : IdGenerator.getUniqueID(),
    name: trimmedName,
    brands: (trimmedBrand == null || trimmedBrand.isEmpty)
        ? null
        : trimmedBrand,
    url: null,
    mealQuantity: null,
    mealUnit: unit,
    servingQuantity: null,
    servingUnit: null,
    servingSize: null,
    nutriments: MealNutrimentsEntity(
      energyKcal100: caloriesPer100,
      carbohydrates100: carbsPer100,
      fat100: fatPer100,
      proteins100: proteinPer100,
      sugars100: null,
      saturatedFat100: null,
      fiber100: null,
    ),
    source: MealSourceEntity.custom,
  );
  await customMeals.saveCustomMeal(MealDBO.fromMealEntity(entity));
  return true;
}

Future<bool> ensureCustomMealForMealPlanFoodEntry({
  required CustomMealDataSource customMeals,
  required MealPlanFoodEntry food,
}) {
  return ensureCustomMealForPlanFood(
    customMeals: customMeals,
    name: food.foodName,
    brand: food.brand,
    caloriesPer100: food.caloriesPer100,
    proteinPer100: food.proteinPer100,
    fatPer100: food.fatPer100,
    carbsPer100: food.carbsPer100,
    unit: food.unit,
    preferredCode: food.foodId,
  );
}

Future<bool> ensureCustomMealForMealPlanEntryEntity({
  required CustomMealDataSource customMeals,
  required MealPlanEntryEntity entry,
}) {
  return ensureCustomMealForPlanFood(
    customMeals: customMeals,
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
