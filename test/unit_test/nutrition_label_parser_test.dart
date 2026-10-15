import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/nutrition_label/domain/nutrition_label_entity.dart';
import 'package:opennutritracker/features/nutrition_label/domain/nutrition_label_parser.dart';

void main() {
  group('nutritionLabelFromJson', () {
    test('parses a per-serving US-style panel', () {
      final label = nutritionLabelFromJson({
        'name': 'Oat Crunch',
        'brands': 'Fitty',
        'barcode': '4001724039143',
        'serving_quantity': 40,
        'serving_unit': 'g',
        'basis': 'per_serving',
        'energy_kcal': 160,
        'carbohydrates_g': 28,
        'fat_g': 3,
        'proteins_g': 5,
        'fiber_g': 4,
        'sodium_mg': 120,
      });

      expect(label.name, 'Oat Crunch');
      expect(label.brands, 'Fitty');
      expect(label.barcode, '4001724039143');
      expect(label.basis, NutritionLabelBasis.perServing);
      expect(label.servingQuantity, 40);
      expect(label.energyKcal, 160);
      expect(label.hasUsableNutrition, isTrue);
    });

    test('scales per-serving values to per-100g on MealEntity', () {
      final meal = nutritionLabelFromJson({
        'basis': 'per_serving',
        'serving_quantity': 50,
        'serving_unit': 'g',
        'energy_kcal': 100,
        'proteins_g': 10,
      }).toMealEntity();

      expect(meal.nutriments.energyKcal100, 200);
      expect(meal.nutriments.proteins100, 20);
      expect(meal.servingQuantity, 50);
      expect(meal.mealUnit, 'g');
      expect(meal.source.name, 'custom');
    });

    test('keeps per-100 values unchanged', () {
      final meal = nutritionLabelFromJson({
        'basis': 'per_100',
        'serving_unit': 'ml',
        'energy_kcal': 42,
        'carbohydrates_g': 5,
      }).toMealEntity();

      expect(meal.nutriments.energyKcal100, 42);
      expect(meal.nutriments.carbohydrates100, 5);
      expect(meal.mealUnit, 'ml');
    });

    test('drops out-of-range and non-numeric junk', () {
      final label = nutritionLabelFromJson({
        'basis': 'per_100',
        'energy_kcal': -5,
        'fat_g': 9999,
        'proteins_g': 'twelve',
        'sodium_mg': 40,
        'barcode': 'abc',
      });

      expect(label.energyKcal, isNull);
      expect(label.fatG, isNull);
      expect(label.proteinsG, isNull);
      expect(label.sodiumMg, 40);
      expect(label.barcode, isNull);
      expect(label.hasUsableNutrition, isFalse);
    });

    test('strips non-digits from a barcode and rejects short codes', () {
      expect(
        nutritionLabelFromJson({
          'basis': 'per_100',
          'energy_kcal': 1,
          'barcode': '4001-7240-3914-3',
        }).barcode,
        '4001724039143',
      );
      expect(
        nutritionLabelFromJson({
          'basis': 'per_100',
          'energy_kcal': 1,
          'barcode': '123',
        }).barcode,
        isNull,
      );
    });

    test('malformed input yields an empty per-100 label', () {
      final label = nutritionLabelFromJson('not a map');
      expect(label.basis, NutritionLabelBasis.per100);
      expect(label.hasUsableNutrition, isFalse);
    });
  });
}
