import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/weekly_macro_target_dbo.dart';

class WeeklyMacroTargetEntity extends Equatable {
  final String id;
  final int dayOfWeek;
  final int calories;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final DateTime updatedAt;

  const WeeklyMacroTargetEntity({
    required this.id,
    required this.dayOfWeek,
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.updatedAt,
  });

  factory WeeklyMacroTargetEntity.fromDBO(WeeklyMacroTargetDBO dbo) {
    return WeeklyMacroTargetEntity(
      id: dbo.id,
      dayOfWeek: dbo.dayOfWeek,
      calories: dbo.calories,
      proteinG: dbo.proteinG,
      fatG: dbo.fatG,
      carbsG: dbo.carbsG,
      updatedAt: dbo.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    dayOfWeek,
    calories,
    proteinG,
    fatG,
    carbsG,
    updatedAt,
  ];
}
