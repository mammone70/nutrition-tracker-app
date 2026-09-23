import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/domain/entity/waist_log_entity.dart';

part 'waist_log_dbo.g.dart';

@HiveType(typeId: 30)
@JsonSerializable()
class WaistLogDBO extends HiveObject {
  @HiveField(0)
  DateTime date;

  /// Circumference in inches (calorie-tracker API unit).
  @HiveField(1)
  double inches;

  @HiveField(2)
  String? note;

  WaistLogDBO({
    required this.date,
    required this.inches,
    this.note,
  });

  factory WaistLogDBO.fromWaistLogEntity(WaistLogEntity entity) {
    return WaistLogDBO(
      date: entity.date,
      inches: entity.inches,
      note: entity.note,
    );
  }

  factory WaistLogDBO.fromJson(Map<String, dynamic> json) =>
      _$WaistLogDBOFromJson(json);

  Map<String, dynamic> toJson() => _$WaistLogDBOToJson(this);
}
