import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/macro_target_dbo.dart';

class MacroTargetEntity extends Equatable {
  final String id;
  final String targetDate;
  final int calories;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final DateTime updatedAt;

  const MacroTargetEntity({
    required this.id,
    required this.targetDate,
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.updatedAt,
  });

  factory MacroTargetEntity.fromDBO(MacroTargetDBO dbo) {
    return MacroTargetEntity(
      id: dbo.id,
      targetDate: dbo.targetDate,
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
    targetDate,
    calories,
    proteinG,
    fatG,
    carbsG,
    updatedAt,
  ];
}

enum MacroTargetSource { override, weekly, none }

class EffectiveMacroTarget extends Equatable {
  final String targetDate;
  final int calories;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final MacroTargetSource source;
  final String? overrideId;
  final int? weeklyDayOfWeek;

  const EffectiveMacroTarget({
    required this.targetDate,
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.source,
    this.overrideId,
    this.weeklyDayOfWeek,
  });

  @override
  List<Object?> get props => [
    targetDate,
    calories,
    proteinG,
    fatG,
    carbsG,
    source,
    overrideId,
    weeklyDayOfWeek,
  ];
}
