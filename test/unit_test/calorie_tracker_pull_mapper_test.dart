import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_sync_mapper.dart';

void main() {
  group('CalorieTrackerSyncMapper pull mappers', () {
    test('dayMealFromRemote maps a remote day meal', () {
      final meal = CalorieTrackerSyncMapper.dayMealFromRemote({
        'id': 'dm-1',
        'planDate': '2026-10-14',
        'mealIndex': 1,
        'name': 'Lunch',
        'mealTime': '12:30',
        'updatedAt': '2026-10-14T10:00:00.000Z',
      });

      expect(meal, isNotNull);
      expect(meal!.id, 'dm-1');
      expect(meal.planDate, '2026-10-14');
      expect(meal.mealIndex, 1);
      expect(meal.name, 'Lunch');
      expect(meal.mealTime, '12:30');
    });

    test('mealPlanEntryFromRemote joins food nutrients', () {
      final entry = CalorieTrackerSyncMapper.mealPlanEntryFromRemote(
        {
          'id': 'mpe-1',
          'planDate': '2026-10-14',
          'dayMealId': 'dm-1',
          'foodId': 'food-1',
          'quantity': 80,
          'unit': 'g',
        },
        {
          'id': 'food-1',
          'name': 'Oats',
          'brand': 'Fitty',
          'nutrientsPer100g': {
            'calories': 350,
            'protein': 12,
            'fat': 7,
            'carbs': 60,
          },
        },
      );

      expect(entry, isNotNull);
      expect(entry!.foodName, 'Oats');
      expect(entry.brand, 'Fitty');
      expect(entry.caloriesPer100, 350);
      expect(entry.proteinPer100, 12);
      expect(entry.quantity, 80);
    });

    test('weeklyMealFromRemote and weekly entry join food', () {
      final meal = CalorieTrackerSyncMapper.weeklyMealFromRemote({
        'id': 'wm-1',
        'dayOfWeek': 0,
        'mealIndex': 0,
        'name': 'Breakfast',
      });
      expect(meal!.dayOfWeek, 0);
      expect(meal.name, 'Breakfast');

      final entry = CalorieTrackerSyncMapper.weeklyMealPlanEntryFromRemote(
        {
          'id': 'wmpe-1',
          'weeklyMealId': 'wm-1',
          'foodId': 'food-2',
          'quantity': 200,
          'unit': 'ml',
        },
        {
          'id': 'food-2',
          'name': 'Milk',
          'nutrientsPer100g': {
            'calories': 42,
            'protein': 3.4,
            'fat': 1,
            'carbs': 5,
          },
        },
      );
      expect(entry!.unit, 'ml');
      expect(entry.caloriesPer100, 42);
      expect(entry.weeklyMealId, 'wm-1');
    });

    test('macro target pull mappers', () {
      final daily = CalorieTrackerSyncMapper.macroTargetFromRemote({
        'id': 'mt-1',
        'targetDate': '2026-10-14',
        'calories': 2200,
        'proteinG': 150,
        'fatG': 70,
        'carbsG': 220,
      });
      expect(daily!.calories, 2200);
      expect(daily.proteinG, 150);

      final weekly = CalorieTrackerSyncMapper.weeklyMacroTargetFromRemote({
        'id': 'wmt-1',
        'dayOfWeek': 5,
        'calories': 2000,
        'proteinG': 140,
        'fatG': 65,
        'carbsG': 200,
      });
      expect(weekly!.dayOfWeek, 5);
      expect(weekly.calories, 2000);
    });

    test('rejects incomplete remote rows', () {
      expect(CalorieTrackerSyncMapper.dayMealFromRemote({}), isNull);
      expect(
        CalorieTrackerSyncMapper.mealPlanEntryFromRemote({'id': 'x'}, null),
        isNull,
      );
      expect(CalorieTrackerSyncMapper.weeklyMealFromRemote({}), isNull);
      expect(CalorieTrackerSyncMapper.macroTargetFromRemote({}), isNull);
    });
  });
}
