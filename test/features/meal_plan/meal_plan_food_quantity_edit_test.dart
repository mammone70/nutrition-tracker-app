import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/meal_plan/meal_plan_editor_widgets.dart';
import 'package:opennutritracker/generated/l10n.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [S.delegate],
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('edit quantity dialog updates food amount and macros', (
    tester,
  ) async {
    final food = EditableMealPlanFood(
      id: '1',
      foodId: 'food-1',
      foodName: 'Rice',
      caloriesPer100: 130,
      proteinPer100: 2.7,
      fatPer100: 0.3,
      carbsPer100: 28,
      quantity: 100,
      unit: 'g',
    );

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () =>
                  showEditMealPlanFoodQuantityDialog(context, food: food),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Rice'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(food.quantity, 200);
    expect(food.calories, closeTo(260, 0.01));
  });

  testWidgets('buildMealBlocksEditor opens edit sheet on food tap', (
    tester,
  ) async {
    final meals = [
      EditableMealBlock(
        id: 'm1',
        mealIndex: 0,
        name: 'Breakfast',
        entries: [
          EditableMealPlanFood(
            id: 'f1',
            foodId: 'food-1',
            foodName: 'Banana',
            caloriesPer100: 89,
            proteinPer100: 1.1,
            fatPer100: 0.3,
            carbsPer100: 23,
            quantity: 120,
            unit: 'g',
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => SingleChildScrollView(
            child: buildMealBlocksEditor(
              context: context,
              meals: meals,
              onChanged: () {},
              onAddFood: () async {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('meal-plan-food-edit-quantity'),
      findsOneWidget,
    );
    await tester.enterText(
      find.bySemanticsIdentifier('meal-plan-food-edit-quantity'),
      '80',
    );
    await tester.tap(find.bySemanticsIdentifier('meal-plan-food-edit-save'));
    await tester.pumpAndSettle();

    expect(meals.first.entries.first.quantity, 80);
  });
}
