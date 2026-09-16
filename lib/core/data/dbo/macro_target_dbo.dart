import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';

part 'macro_target_dbo.g.dart';

@HiveType(typeId: 24)
@JsonSerializable()
class MacroTargetDBO extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String targetDate;
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

  MacroTargetDBO({
    required this.id,
    required this.targetDate,
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.updatedAt,
  });

  factory MacroTargetDBO.fromEntity(MacroTargetEntity entity) {
    return MacroTargetDBO(
      id: entity.id,
      targetDate: entity.targetDate,
      calories: entity.calories,
      proteinG: entity.proteinG,
      fatG: entity.fatG,
      carbsG: entity.carbsG,
      updatedAt: entity.updatedAt,
    );
  }

  factory MacroTargetDBO.fromJson(Map<String, dynamic> json) =>
      _$MacroTargetDBOFromJson(json);

  Map<String, dynamic> toJson() => _$MacroTargetDBOToJson(this);
}
