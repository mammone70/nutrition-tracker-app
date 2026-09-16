import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';

part 'day_meal_dbo.g.dart';

@HiveType(typeId: 27)
@JsonSerializable()
class DayMealDBO extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String planDate;
  @HiveField(2)
  int mealIndex;
  @HiveField(3)
  String name;
  @HiveField(4)
  String? mealTime;
  @HiveField(5)
  DateTime updatedAt;

  DayMealDBO({
    required this.id,
    required this.planDate,
    required this.mealIndex,
    required this.name,
    this.mealTime,
    required this.updatedAt,
  });

  factory DayMealDBO.fromEntity(DayMealEntity entity) {
    return DayMealDBO(
      id: entity.id,
      planDate: entity.planDate,
      mealIndex: entity.mealIndex,
      name: entity.name,
      mealTime: entity.mealTime,
      updatedAt: entity.updatedAt,
    );
  }

  factory DayMealDBO.fromJson(Map<String, dynamic> json) =>
      _$DayMealDBOFromJson(json);

  Map<String, dynamic> toJson() => _$DayMealDBOToJson(this);
}
