import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opennutritracker/core/presentation/main_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/main.dart' as app;

/// Single-boot smoke for the whole first-run path. Everything here shares
/// one `app.main()` deliberately: `initLocator()` registers its GetIt
/// singletons without a re-registration guard, so a second `app.main()` in
/// the same process would throw. Keeping the checks in one boot (rather than
/// several test files) is what lets the suite run unsharded — a single
/// `flutter test integration_test/` per platform that pays the build and
/// simulator cost once.
///
/// Fresh installs seed a default profile and land on MainScreen — profile
/// questionnaires are optional, not a gate.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fresh install boots cleanly into the main app without onboarding',
    (WidgetTester tester) async {
      final caught = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        caught.add(details);
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);

      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 30));

      expect(
        find.byType(MaterialApp),
        findsOneWidget,
        reason: 'app should reach a MaterialApp',
      );
      expect(
        caught,
        isEmpty,
        reason:
            'no Flutter errors should fire during boot, got: '
            '${caught.map((e) => e.exception).toList()}',
      );

      expect(
        find.byType(MainScreen),
        findsOneWidget,
        reason: 'fresh install should open the main app without onboarding',
      );

      // Localisation is live (app title from ARB).
      final context = tester.element(find.byType(MainScreen));
      final title = S.of(context).appTitle;
      expect(title, isNotEmpty);
      expect(find.text(title), findsWidgets);
      if (S.of(context).localeName.startsWith('en')) {
        expect(title, 'Fitty Kitties');
      }
    },
  );
}
