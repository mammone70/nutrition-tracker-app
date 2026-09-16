import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/domain/entity/weekly_macro_target_entity.dart';
import 'package:opennutritracker/core/domain/usecase/weekly_macro_target_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/meal_plan/weekly_macro_targets_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class _FakeGetWeekly extends Fake implements GetWeeklyMacroTargetsUsecase {
  @override
  Future<List<WeeklyMacroTargetEntity>> getAll() async => [
        WeeklyMacroTargetEntity(
          id: 'mon',
          dayOfWeek: 0,
          calories: 2200,
          proteinG: 180,
          fatG: 70,
          carbsG: 215,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ];
}

class _FakeSaveWeekly extends Fake implements SaveWeeklyMacroTargetsUsecase {
  @override
  Future<void> saveAll(List<WeeklyMacroTargetEntity> targets) async {}
}

void main() {
  setUp(() async {
    await GetIt.I.reset();
    locator.registerSingleton<GetWeeklyMacroTargetsUsecase>(_FakeGetWeekly());
    locator.registerSingleton<SaveWeeklyMacroTargetsUsecase>(_FakeSaveWeekly());
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  testWidgets('weekly macro targets screen loads weekday fields', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: const WeeklyMacroTargetsScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Weekly calorie & macro targets'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('2200'), findsOneWidget);
    expect(find.text('180'), findsOneWidget);
  });
}
