import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/domain/entity/weekly_macro_target_entity.dart';

part 'weekly_macro_target_dbo.g.dart';

@HiveType(typeId: 23)
@JsonSerializable()
class WeeklyMacroTargetDBO extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  int dayOfWeek;
  @HiveField(2)
  int calories;
  @HiveField(3)
  double proteinG;
  @HiveField(4)
  double fatG;
  @HiveField(5)
  double carbsG;
  @HiveField(6)
  DateTime updatedAt;

  WeeklyMacroTargetDBO({
    required this.id,
    required this.dayOfWeek,
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.updatedAt,
  });

  factory WeeklyMacroTargetDBO.fromEntity(WeeklyMacroTargetEntity entity) {
    return WeeklyMacroTargetDBO(
      id: entity.id,
      dayOfWeek: entity.dayOfWeek,
      calories: entity.calories,
      proteinG: entity.proteinG,
      fatG: entity.fatG,
      carbsG: entity.carbsG,
      updatedAt: entity.updatedAt,
    );
  }

  factory WeeklyMacroTargetDBO.fromJson(Map<String, dynamic> json) =>
      _$WeeklyMacroTargetDBOFromJson(json);

  Map<String, dynamic> toJson() => _$WeeklyMacroTargetDBOToJson(this);
}
