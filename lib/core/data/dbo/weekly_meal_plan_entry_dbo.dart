import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_plan_entry_entity.dart';

part 'weekly_meal_plan_entry_dbo.g.dart';

@HiveType(typeId: 26)
@JsonSerializable()
class WeeklyMealPlanEntryDBO extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String weeklyMealId;
  @HiveField(2)
  String foodId;
  @HiveField(3)
  String foodName;
  @HiveField(4)
  String? brand;
  @HiveField(5)
  double caloriesPer100;
  @HiveField(6)
  double proteinPer100;
  @HiveField(7)
  double fatPer100;
  @HiveField(8)
  double carbsPer100;
  @HiveField(9)
  double quantity;
  @HiveField(10)
  String unit;
  @HiveField(11)
  DateTime updatedAt;

  WeeklyMealPlanEntryDBO({
    required this.id,
    required this.weeklyMealId,
    required this.foodId,
    required this.foodName,
    this.brand,
    required this.caloriesPer100,
    required this.proteinPer100,
    required this.fatPer100,
    required this.carbsPer100,
    required this.quantity,
    required this.unit,
    required this.updatedAt,
  });

  factory WeeklyMealPlanEntryDBO.fromEntity(WeeklyMealPlanEntryEntity entity) {
    return WeeklyMealPlanEntryDBO(
      id: entity.id,
      weeklyMealId: entity.weeklyMealId,
      foodId: entity.foodId,
      foodName: entity.foodName,
      brand: entity.brand,
      caloriesPer100: entity.caloriesPer100,
      proteinPer100: entity.proteinPer100,
      fatPer100: entity.fatPer100,
      carbsPer100: entity.carbsPer100,
      quantity: entity.quantity,
      unit: entity.unit,
      updatedAt: entity.updatedAt,
    );
  }

  factory WeeklyMealPlanEntryDBO.fromJson(Map<String, dynamic> json) =>
      _$WeeklyMealPlanEntryDBOFromJson(json);

  Map<String, dynamic> toJson() => _$WeeklyMealPlanEntryDBOToJson(this);
}
