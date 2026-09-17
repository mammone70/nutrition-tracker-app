import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/domain/usecase/ensure_custom_meal_for_plan_food.dart';

import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';

MealDBO _meal({required String name, String? brands, double kcal = 100}) =>
    MealDBO(
      code: null,
      name: name,
      brands: brands,
      thumbnailImageUrl: null,
      mainImageUrl: null,
      url: null,
      mealQuantity: '100',
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: 'g',
      servingSize: null,
      nutriments: MealNutrimentsDBO(
        energyKcal100: kcal,
        carbohydrates100: 10,
        fat100: 5,
        proteins100: 20,
        sugars100: null,
        saturatedFat100: null,
        fiber100: null,
      ),
      source: MealSourceDBO.custom,
    );

void main() {
  late Box<MealDBO> box;
  late CustomMealDataSource ds;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('.');
    registerHiveAdaptersOnce();
  });

  setUp(() async {
    box = await Hive.openBox<MealDBO>(
      'ensure_custom_meal_${DateTime.now().microsecondsSinceEpoch}',
    );
    ds = CustomMealDataSource(FakeHiveDBProvider(customMealBox: box));
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  test('saves unmatched meal-plan foods into the custom food DB', () async {
    final saved = await ensureCustomMealForPlanFood(
      customMeals: ds,
      name: 'Chicken breast',
      brand: null,
      caloriesPer100: 165,
      proteinPer100: 31,
      fatPer100: 3.6,
      carbsPer100: 0,
    );

    expect(saved, isTrue);
    expect(ds.getAllCustomMeals(), hasLength(1));
    expect(ds.getAllCustomMeals().single.name, 'Chicken breast');
    expect(ds.getAllCustomMeals().single.nutriments.proteins100, 31);
  });

  test('does not duplicate an existing custom meal by name', () async {
    await ds.saveCustomMeal(_meal(name: 'Oats', kcal: 380));

    final saved = await ensureCustomMealForPlanFood(
      customMeals: ds,
      name: 'oats',
      brand: null,
      caloriesPer100: 389,
      proteinPer100: 17,
      fatPer100: 7,
      carbsPer100: 66,
    );

    expect(saved, isFalse);
    expect(ds.getAllCustomMeals(), hasLength(1));
    expect(ds.getAllCustomMeals().single.nutriments.energyKcal100, 380);
  });

  test('treats different brands as distinct foods', () async {
    await ds.saveCustomMeal(_meal(name: 'Yogurt', brands: 'Brand A'));

    final saved = await ensureCustomMealForPlanFood(
      customMeals: ds,
      name: 'Yogurt',
      brand: 'Brand B',
      caloriesPer100: 60,
      proteinPer100: 10,
      fatPer100: 0,
      carbsPer100: 5,
    );

    expect(saved, isTrue);
    expect(ds.getAllCustomMeals(), hasLength(2));
  });
}
