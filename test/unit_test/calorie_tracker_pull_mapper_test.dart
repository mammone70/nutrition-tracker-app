import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_sync_mapper.dart';
import 'package:opennutritracker/core/sync/sync_operation.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('CalorieTrackerSyncMapper syncFoodId / sanitizePushOperation', () {
    test('maps agent: food codes to a stable UUID', () {
      final a = CalorieTrackerSyncMapper.syncFoodId('agent:oatmeal');
      final b = CalorieTrackerSyncMapper.syncFoodId('agent:oatmeal');
      expect(Uuid.isValidUUID(fromString: a), isTrue);
      expect(a, b);
      expect(a, isNot('agent:oatmeal'));
    });

    test('leaves real UUIDs unchanged', () {
      const id = '11111111-1111-4111-8111-111111111111';
      expect(CalorieTrackerSyncMapper.syncFoodId(id), id);
    });

    test('sanitizes a foods push with an agent: entityId', () {
      final op = SyncOperation(
        id: 'op-1',
        entityType: SyncEntityType.foods,
        action: SyncAction.create,
        entityId: 'agent:oatmeal',
        payload: {
          'name': 'Oatmeal',
          'nutrientsPer100g': {
            'calories': 350,
            'protein': 12,
            'fat': 7,
            'carbs': 60,
          },
        },
        clientUpdatedAt: DateTime.utc(2026, 10, 14),
        enqueuedAt: DateTime.utc(2026, 10, 14),
      );
      final fixed = CalorieTrackerSyncMapper.sanitizePushOperation(op);
      expect(fixed, isNotNull);
      expect(Uuid.isValidUUID(fromString: fixed!.entityId), isTrue);
      expect(
        fixed.entityId,
        CalorieTrackerSyncMapper.syncFoodId('agent:oatmeal'),
      );
    });

    test('sanitizes meal_plan_entries payload foodId', () {
      final op = SyncOperation(
        id: 'op-2',
        entityType: SyncEntityType.mealPlanEntries,
        action: SyncAction.create,
        entityId: '22222222-2222-4222-8222-222222222222',
        payload: {
          'planDate': '2026-10-14',
          'dayMealId': '33333333-3333-4333-8333-333333333333',
          'foodId': 'agent:oatmeal',
          'quantity': 80,
          'unit': 'g',
        },
        clientUpdatedAt: DateTime.utc(2026, 10, 14),
        enqueuedAt: DateTime.utc(2026, 10, 14),
      );
      final fixed = CalorieTrackerSyncMapper.sanitizePushOperation(op);
      expect(fixed, isNotNull);
      expect(
        fixed!.payload!['foodId'],
        CalorieTrackerSyncMapper.syncFoodId('agent:oatmeal'),
      );
    });

    test('drops deletes for non-UUID entity ids', () {
      final op = SyncOperation(
        id: 'op-3',
        entityType: SyncEntityType.mealPlanEntries,
        action: SyncAction.delete,
        entityId: 'agent:oatmeal',
        clientUpdatedAt: DateTime.utc(2026, 10, 14),
        enqueuedAt: DateTime.utc(2026, 10, 14),
      );
      expect(CalorieTrackerSyncMapper.sanitizePushOperation(op), isNull);
    });
  });

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
