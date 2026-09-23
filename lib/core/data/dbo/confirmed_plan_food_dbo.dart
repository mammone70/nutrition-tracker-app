import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'confirmed_plan_food_dbo.g.dart';

/// Links a meal-plan food entry to the diary intake created when it was
/// confirmed, so the UI can show confirmed state and support unconfirm.
@HiveType(typeId: 29)
@JsonSerializable()
class ConfirmedPlanFoodDBO extends HiveObject {
  @HiveField(0)
  String planDate;

  @HiveField(1)
  String entryId;

  @HiveField(2)
  String intakeId;

  ConfirmedPlanFoodDBO({
    required this.planDate,
    required this.entryId,
    required this.intakeId,
  });

  static String keyFor({required String planDate, required String entryId}) =>
      '$planDate|$entryId';

  String get boxKey => keyFor(planDate: planDate, entryId: entryId);

  factory ConfirmedPlanFoodDBO.fromJson(Map<String, dynamic> json) =>
      _$ConfirmedPlanFoodDBOFromJson(json);

  Map<String, dynamic> toJson() => _$ConfirmedPlanFoodDBOToJson(this);
}
