import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/waist_log_dbo.dart';

class WaistLogEntity extends Equatable {
  final DateTime date;

  /// Circumference in inches (matches calorie-tracker REST API).
  final double inches;
  final String? note;

  const WaistLogEntity({
    required this.date,
    required this.inches,
    this.note,
  });

  factory WaistLogEntity.fromWaistLogDBO(WaistLogDBO dbo) {
    return WaistLogEntity(
      date: dbo.date,
      inches: dbo.inches,
      note: dbo.note,
    );
  }

  @override
  List<Object?> get props => [date, inches, note];
}
