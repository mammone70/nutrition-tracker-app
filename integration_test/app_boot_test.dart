import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opennutritracker/core/presentation/main_screen.dart';
import 'package:opennutritracker/core/presentation/widgets/home_appbar.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/main.dart' as app;

/// Single-boot smoke for the whole first-run path. Everything here shares
/// one `app.main()` deliberately: `initLocator()` registers its GetIt
/// singletons without a re-registration guard, so a second `app.main()` in
/// the same process would throw.
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
      expect(
        find.byType(HomeAppbar),
        findsOneWidget,
        reason: 'main home should show the branded app bar',
      );

      final context = tester.element(find.byType(MainScreen));
      final title = S.of(context).appTitle;
      expect(title, isNotEmpty);
      if (S.of(context).localeName.startsWith('en')) {
        expect(
          title,
          'Fitty Kitties',
          reason: 'English appTitle should be Fitty Kitties',
        );
      }

      // HomeAppbar renders the title via RichText/TextSpan, so assert the
      // span text rather than find.text (which only matches Text widgets).
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains(title),
        ),
        findsWidgets,
        reason: 'app title should render in the home app bar',
      );
    },
  );
}
