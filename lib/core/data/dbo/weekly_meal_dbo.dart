import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_entity.dart';

part 'weekly_meal_dbo.g.dart';

@HiveType(typeId: 25)
@JsonSerializable()
class WeeklyMealDBO extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  int dayOfWeek;
  @HiveField(2)
  int mealIndex;
  @HiveField(3)
  String name;
  @HiveField(4)
  String? mealTime;
  @HiveField(5)
  DateTime updatedAt;

  WeeklyMealDBO({
    required this.id,
    required this.dayOfWeek,
    required this.mealIndex,
    required this.name,
    this.mealTime,
    required this.updatedAt,
  });

  factory WeeklyMealDBO.fromEntity(WeeklyMealEntity entity) {
    return WeeklyMealDBO(
      id: entity.id,
      dayOfWeek: entity.dayOfWeek,
      mealIndex: entity.mealIndex,
      name: entity.name,
      mealTime: entity.mealTime,
      updatedAt: entity.updatedAt,
    );
  }

  factory WeeklyMealDBO.fromJson(Map<String, dynamic> json) =>
      _$WeeklyMealDBOFromJson(json);

  Map<String, dynamic> toJson() => _$WeeklyMealDBOToJson(this);
}
