import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/calc/macro_calories.dart';
import 'package:opennutritracker/core/utils/meal_plan_utils.dart';

void main() {
  group('macro_calories', () {
    test('caloriesFromMacros uses Atwater factors', () {
      // 180×4 + 70×9 + 200×4 = 2150
      expect(caloriesFromMacros(180, 70, 200), 2150);
    });

    test('macrosMatchCalories allows ±1 kcal', () {
      expect(macrosMatchCalories(2150, 180, 70, 200), isTrue);
      expect(macrosMatchCalories(2151, 180, 70, 200), isTrue);
      expect(macrosMatchCalories(2149, 180, 70, 200), isTrue);
      expect(macrosMatchCalories(2160, 180, 70, 200), isFalse);
    });

    test('macroCaloriesError reports mismatch', () {
      expect(macroCaloriesError(2150, 180, 70, 200), isNull);
      expect(macroCaloriesError(2000, 180, 70, 200), contains('2150'));
    });
  });

  group('meal_plan_utils', () {
    test('dayOfWeekFromDate uses Monday=0', () {
      // 2026-09-16 is a Wednesday
      expect(dayOfWeekFromDate(DateTime(2026, 9, 16)), 2);
      expect(dayOfWeekFromDate(DateTime(2026, 9, 14)), 0); // Monday
      expect(dayOfWeekFromDate(DateTime(2026, 9, 20)), 6); // Sunday
    });

    test('defaultMealName covers common slots', () {
      expect(defaultMealName(0), 'Breakfast');
      expect(defaultMealName(1), 'Lunch');
      expect(defaultMealName(2), 'Dinner');
      expect(defaultMealName(3), 'Snack');
      expect(defaultMealName(4), 'Meal 5');
    });
  });
}
