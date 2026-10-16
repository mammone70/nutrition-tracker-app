import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/meal_plan/meal_plan_editor_widgets.dart';

MealEntity _meal({
  String? name = 'Oats',
  String? brands,
  String? mealUnit = 'g',
  double? energyKcal100 = 389,
  double? proteins100 = 17,
  double? fat100 = 7,
  double? carbs100 = 66,
  double? servingQuantity,
}) {
  return MealEntity(
    code: 'oats-1',
    name: name,
    brands: brands,
    url: null,
    mealQuantity: null,
    mealUnit: mealUnit,
    servingQuantity: servingQuantity,
    servingUnit: servingQuantity != null ? 'g' : null,
    servingSize: null,
    nutriments: MealNutrimentsEntity(
      energyKcal100: energyKcal100,
      carbohydrates100: carbs100,
      fat100: fat100,
      proteins100: proteins100,
      sugars100: null,
      saturatedFat100: null,
      fiber100: null,
    ),
    source: MealSourceEntity.custom,
  );
}

void main() {
  group('editableFoodFromMeal', () {
    test('stores grams for a solid amount in g', () {
      final food = editableFoodFromMeal(
        meal: _meal(),
        amount: 50,
        unit: 'g',
        id: 'fixed-id',
      );

      expect(food, isNotNull);
      expect(food!.id, 'fixed-id');
      expect(food.foodName, 'Oats');
      expect(food.quantity, 50);
      expect(food.unit, 'g');
      expect(food.caloriesPer100, 389);
      expect(food.calories, closeTo(194.5, 0.01));
    });

    test('converts servings using scalableServingQuantity', () {
      final food = editableFoodFromMeal(
        meal: _meal(servingQuantity: 40),
        amount: 2,
        unit: 'serving',
      );

      expect(food, isNotNull);
      expect(food!.quantity, 80);
      expect(food.unit, 'g');
    });

    test('uses ml as base unit for liquids', () {
      final food = editableFoodFromMeal(
        meal: _meal(name: 'Milk', mealUnit: 'ml', energyKcal100: 42),
        amount: 250,
        unit: 'ml',
      );

      expect(food, isNotNull);
      expect(food!.quantity, 250);
      expect(food.unit, 'ml');
    });

    test('returns null when serving cannot be converted', () {
      final food = editableFoodFromMeal(
        meal: _meal(servingQuantity: null),
        amount: 1,
        unit: 'serving',
      );

      expect(food, isNull);
    });

    test('returns null for non-positive converted amounts', () {
      final food = editableFoodFromMeal(meal: _meal(), amount: 0, unit: 'g');

      expect(food, isNull);
    });
  });
}
