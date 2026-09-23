import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/moving_average.dart';

void main() {
  group('sevenDayMovingAverage', () {
    test('returns empty when end is before start', () {
      final result = sevenDayMovingAverage(
        from: DateTime(2026, 9, 10),
        to: DateTime(2026, 9, 1),
        valuesByDay: const {},
      );
      expect(result, isEmpty);
    });

    test('skips missing days in the window mean', () {
      final from = DateTime(2026, 9, 1);
      final to = DateTime(2026, 9, 7);
      final values = <String, double>{
        DateTime(2026, 9, 1).toParsedDay(): 70,
        DateTime(2026, 9, 3).toParsedDay(): 72,
        DateTime(2026, 9, 7).toParsedDay(): 74,
      };

      final points = sevenDayMovingAverage(
        from: from,
        to: to,
        valuesByDay: values,
      );

      expect(points, hasLength(7));
      expect(points.first.value, 70);
      expect(points.first.average7d, 70);
      expect(points[2].value, 72);
      expect(points[2].average7d, closeTo((70 + 72) / 2, 0.001));
      expect(points.last.value, 74);
      expect(points.last.average7d, closeTo((70 + 72 + 74) / 3, 0.001));
      expect(points[1].value, isNull);
      expect(points[1].average7d, 70);
    });

    test('average is null when the window has no values', () {
      final points = sevenDayMovingAverage(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 2),
        valuesByDay: const {},
      );
      expect(points.every((p) => p.average7d == null), isTrue);
    });
  });
}
