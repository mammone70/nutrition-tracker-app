import 'package:opennutritracker/core/utils/extensions.dart';

/// One day in a sparse daily series with an optional 7-day moving average.
class MovingAveragePoint {
  final DateTime date;
  final double? value;
  final double? average7d;

  const MovingAveragePoint({
    required this.date,
    this.value,
    this.average7d,
  });
}

/// Builds a day-by-day series from [from] through [to] (inclusive) and
/// computes a trailing 7-day mean of available values ending on each day.
///
/// Missing days contribute nothing to the mean (not zero-filled). The average
/// is null until at least one value exists in the window.
List<MovingAveragePoint> sevenDayMovingAverage({
  required DateTime from,
  required DateTime to,
  required Map<String, double> valuesByDay,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  if (end.isBefore(start)) return const [];

  final points = <MovingAveragePoint>[];
  for (
    var day = start;
    !day.isAfter(end);
    day = day.add(const Duration(days: 1))
  ) {
    final key = day.toParsedDay();
    final value = valuesByDay[key];
    final window = <double>[];
    for (var i = 0; i < 7; i++) {
      final d = day.subtract(Duration(days: i));
      final v = valuesByDay[d.toParsedDay()];
      if (v != null) window.add(v);
    }
    points.add(
      MovingAveragePoint(
        date: day,
        value: value,
        average7d: window.isEmpty
            ? null
            : window.reduce((a, b) => a + b) / window.length,
      ),
    );
  }
  return points;
}
