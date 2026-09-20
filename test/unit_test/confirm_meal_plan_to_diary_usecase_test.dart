import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/confirmed_plan_food_data_source.dart';
import 'package:opennutritracker/core/data/dbo/confirmed_plan_food_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/confirm_meal_plan_to_diary_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';

import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';

class _FakeAddIntakeUsecase implements AddIntakeUsecase {
  final List<IntakeEntity> logged = [];

  @override
  Future<void> addIntake(IntakeEntity intakeEntity) async {
    logged.add(intakeEntity);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeAddTrackedDayUsecase implements AddTrackedDayUsecase {
  var hasDay = false;
  var newDayCalls = 0;
  double caloriesTracked = 0;
  double carbsTracked = 0;
  double fatTracked = 0;
  double proteinTracked = 0;
  double caloriesRemoved = 0;
  double carbsRemoved = 0;
  double fatRemoved = 0;
  double proteinRemoved = 0;

  @override
  Future<bool> hasTrackedDay(DateTime day) async => hasDay;

  @override
  Future<void> addNewTrackedDay(
    DateTime day,
    double totalKcalGoal,
    double totalCarbsGoal,
    double totalFatGoal,
    double totalProteinGoal,
  ) async {
    newDayCalls++;
    hasDay = true;
  }

  @override
  Future<void> addDayCaloriesTracked(DateTime day, double calories) async {
    caloriesTracked += calories;
  }

  @override
  Future<void> addDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {
    this.carbsTracked += carbsTracked ?? 0;
    this.fatTracked += fatTracked ?? 0;
    this.proteinTracked += proteinTracked ?? 0;
  }

  @override
  Future<void> removeDayCaloriesTracked(DateTime day, double calories) async {
    caloriesRemoved += calories;
  }

  @override
  Future<void> removeDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {
    carbsRemoved += carbsTracked ?? 0;
    fatRemoved += fatTracked ?? 0;
    proteinRemoved += proteinTracked ?? 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetIntakeUsecase implements GetIntakeUsecase {
  final Map<String, IntakeEntity> byId = {};

  @override
  Future<IntakeEntity?> getIntakeById(String id) async => byId[id];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeDeleteIntakeUsecase implements DeleteIntakeUsecase {
  final List<String> deletedIds = [];

  @override
  Future<void> deleteIntake(IntakeEntity intakeEntity) async {
    deletedIds.add(intakeEntity.id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

MealPlanFoodEntry _food({
  String id = 'entry-1',
  String name = 'Oats',
  double quantity = 100,
  double kcal100 = 370,
  double protein100 = 13,
  double fat100 = 7,
  double carbs100 = 60,
}) {
  return MealPlanFoodEntry(
    id: id,
    foodId: 'food-$name',
    foodName: name,
    caloriesPer100: kcal100,
    proteinPer100: protein100,
    fatPer100: fat100,
    carbsPer100: carbs100,
    quantity: quantity,
    unit: 'g',
  );
}

EffectiveMealBlock _meal({
  required int mealIndex,
  required String name,
  List<MealPlanFoodEntry>? entries,
}) {
  return EffectiveMealBlock(
    id: 'meal-$mealIndex',
    mealIndex: mealIndex,
    name: name,
    source: MealPlanSource.override,
    entries: entries ?? [_food()],
  );
}

void main() {
  group('intakeTypeForMealPlan', () {
    test('maps common English and German meal names', () {
      expect(
        intakeTypeForMealPlan(mealIndex: 9, name: 'Breakfast'),
        IntakeTypeEntity.breakfast,
      );
      expect(
        intakeTypeForMealPlan(mealIndex: 9, name: 'Frühstück'),
        IntakeTypeEntity.breakfast,
      );
      expect(
        intakeTypeForMealPlan(mealIndex: 9, name: 'Lunch bowl'),
        IntakeTypeEntity.lunch,
      );
      expect(
        intakeTypeForMealPlan(mealIndex: 9, name: 'Mittagessen'),
        IntakeTypeEntity.lunch,
      );
      expect(
        intakeTypeForMealPlan(mealIndex: 9, name: 'Dinner'),
        IntakeTypeEntity.dinner,
      );
      expect(
        intakeTypeForMealPlan(mealIndex: 9, name: 'Abendessen'),
        IntakeTypeEntity.dinner,
      );
      expect(
        intakeTypeForMealPlan(mealIndex: 9, name: 'Evening snack'),
        IntakeTypeEntity.snack,
      );
    });

    test('falls back to meal index when the name is unknown', () {
      expect(
        intakeTypeForMealPlan(mealIndex: 0, name: 'Meal A'),
        IntakeTypeEntity.breakfast,
      );
      expect(
        intakeTypeForMealPlan(mealIndex: 1, name: 'Meal B'),
        IntakeTypeEntity.lunch,
      );
      expect(
        intakeTypeForMealPlan(mealIndex: 2, name: 'Meal C'),
        IntakeTypeEntity.dinner,
      );
      expect(
        intakeTypeForMealPlan(mealIndex: 3, name: 'Meal D'),
        IntakeTypeEntity.snack,
      );
    });
  });

  group('ConfirmMealPlanToDiaryUsecase', () {
    late Box<ConfirmedPlanFoodDBO> confirmedBox;
    late ConfirmedPlanFoodDataSource confirmedLinks;
    late _FakeAddIntakeUsecase addIntake;
    late _FakeAddTrackedDayUsecase addTrackedDay;
    late ConfirmMealPlanToDiaryUsecase usecase;
    final day = DateTime(2026, 9, 17);

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerHiveAdaptersOnce();
    });

    setUp(() async {
      Hive.init('.');
      confirmedBox = await Hive.openBox<ConfirmedPlanFoodDBO>(
        'confirmed_plan_food_test_${DateTime.now().microsecondsSinceEpoch}',
      );
      confirmedLinks = ConfirmedPlanFoodDataSource(
        FakeHiveDBProvider(confirmedPlanFoodBox: confirmedBox),
      );
      addIntake = _FakeAddIntakeUsecase();
      addTrackedDay = _FakeAddTrackedDayUsecase();
      usecase = ConfirmMealPlanToDiaryUsecase(
        addIntake,
        addTrackedDay,
        confirmedLinks,
      );
    });

    tearDown(() async {
      await confirmedBox.deleteFromDisk();
    });

    test(
      'confirmFood logs one intake and creates a tracked day when missing',
      () async {
        final meal = _meal(mealIndex: 0, name: 'Breakfast');
        final count = await usecase.confirmFood(
          food: meal.entries.first,
          meal: meal,
          day: day,
          calorieGoal: 2000,
          carbsGoal: 200,
          fatGoal: 70,
          proteinGoal: 150,
        );

        expect(count, 1);
        expect(addIntake.logged, hasLength(1));
        expect(addIntake.logged.single.type, IntakeTypeEntity.breakfast);
        expect(addIntake.logged.single.amount, 100);
        expect(addIntake.logged.single.meal.name, 'Oats');
        expect(addTrackedDay.newDayCalls, 1);
        expect(addTrackedDay.caloriesTracked, closeTo(370, 0.01));
        expect(addTrackedDay.proteinTracked, closeTo(13, 0.01));
        expect(
          usecase.confirmedIntakeIdsForDate(day),
          containsPair('entry-1', addIntake.logged.single.id),
        );
      },
    );

    test('confirmFood skips already-confirmed entries', () async {
      final meal = _meal(mealIndex: 0, name: 'Breakfast');
      await usecase.confirmFood(
        food: meal.entries.first,
        meal: meal,
        day: day,
        calorieGoal: 2000,
        carbsGoal: 200,
        fatGoal: 70,
        proteinGoal: 150,
      );
      final second = await usecase.confirmFood(
        food: meal.entries.first,
        meal: meal,
        day: day,
        calorieGoal: 2000,
        carbsGoal: 200,
        fatGoal: 70,
        proteinGoal: 150,
      );

      expect(second, 0);
      expect(addIntake.logged, hasLength(1));
    });

    test('confirmMeal logs every food in the block', () async {
      addTrackedDay.hasDay = true;
      final meal = _meal(
        mealIndex: 1,
        name: 'Lunch',
        entries: [
          _food(id: 'a', name: 'Rice', quantity: 150, kcal100: 130),
          _food(id: 'b', name: 'Chicken', quantity: 100, kcal100: 165),
        ],
      );

      final count = await usecase.confirmMeal(
        meal: meal,
        day: day,
        calorieGoal: 2000,
        carbsGoal: 200,
        fatGoal: 70,
        proteinGoal: 150,
      );

      expect(count, 2);
      expect(addIntake.logged, hasLength(2));
      expect(addIntake.logged.map((i) => i.type).toSet(), {
        IntakeTypeEntity.lunch,
      });
      expect(addTrackedDay.newDayCalls, 0);
    });

    test('confirmPlan walks every meal in the plan', () async {
      addTrackedDay.hasDay = true;
      final plan = EffectiveMealPlan(
        source: MealPlanSource.override,
        meals: [
          _meal(mealIndex: 0, name: 'Breakfast'),
          _meal(
            mealIndex: 2,
            name: 'Dinner',
            entries: [
              _food(id: 'd1', name: 'Soup'),
              _food(id: 'd2', name: 'Bread'),
            ],
          ),
        ],
      );

      final count = await usecase.confirmPlan(
        plan: plan,
        day: day,
        calorieGoal: 2000,
        carbsGoal: 200,
        fatGoal: 70,
        proteinGoal: 150,
      );

      expect(count, 3);
      expect(addIntake.logged, hasLength(3));
      expect(addIntake.logged[0].type, IntakeTypeEntity.breakfast);
      expect(addIntake.logged[1].type, IntakeTypeEntity.dinner);
      expect(addIntake.logged[2].type, IntakeTypeEntity.dinner);
    });
  });

  group('UnconfirmMealPlanFoodUsecase', () {
    late Box<ConfirmedPlanFoodDBO> confirmedBox;
    late ConfirmedPlanFoodDataSource confirmedLinks;
    late _FakeAddIntakeUsecase addIntake;
    late _FakeAddTrackedDayUsecase addTrackedDay;
    late _FakeGetIntakeUsecase getIntake;
    late _FakeDeleteIntakeUsecase deleteIntake;
    late ConfirmMealPlanToDiaryUsecase confirm;
    late UnconfirmMealPlanFoodUsecase unconfirm;
    final day = DateTime(2026, 9, 17);

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerHiveAdaptersOnce();
    });

    setUp(() async {
      Hive.init('.');
      confirmedBox = await Hive.openBox<ConfirmedPlanFoodDBO>(
        'unconfirm_plan_food_test_${DateTime.now().microsecondsSinceEpoch}',
      );
      confirmedLinks = ConfirmedPlanFoodDataSource(
        FakeHiveDBProvider(confirmedPlanFoodBox: confirmedBox),
      );
      addIntake = _FakeAddIntakeUsecase();
      addTrackedDay = _FakeAddTrackedDayUsecase();
      getIntake = _FakeGetIntakeUsecase();
      deleteIntake = _FakeDeleteIntakeUsecase();
      confirm = ConfirmMealPlanToDiaryUsecase(
        addIntake,
        addTrackedDay,
        confirmedLinks,
      );
      unconfirm = UnconfirmMealPlanFoodUsecase(
        deleteIntake,
        getIntake,
        addTrackedDay,
        confirmedLinks,
      );
    });

    tearDown(() async {
      await confirmedBox.deleteFromDisk();
    });

    test('unconfirmFood deletes diary intake and clears the link', () async {
      final meal = _meal(mealIndex: 0, name: 'Breakfast');
      await confirm.confirmFood(
        food: meal.entries.first,
        meal: meal,
        day: day,
        calorieGoal: 2000,
        carbsGoal: 200,
        fatGoal: 70,
        proteinGoal: 150,
      );
      final intake = addIntake.logged.single;
      getIntake.byId[intake.id] = intake;

      final ok = await unconfirm.unconfirmFood(
        entryId: meal.entries.first.id,
        day: day,
      );

      expect(ok, isTrue);
      expect(deleteIntake.deletedIds, [intake.id]);
      expect(confirm.confirmedIntakeIdsForDate(day), isEmpty);
      expect(addTrackedDay.caloriesRemoved, closeTo(370, 0.01));
    });
  });
}
