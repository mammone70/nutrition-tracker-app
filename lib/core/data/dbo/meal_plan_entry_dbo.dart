import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';

part 'meal_plan_entry_dbo.g.dart';

@HiveType(typeId: 28)
@JsonSerializable()
class MealPlanEntryDBO extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String planDate;
  @HiveField(2)
  String dayMealId;
  @HiveField(3)
  String foodId;
  @HiveField(4)
  String foodName;
  @HiveField(5)
  String? brand;
  @HiveField(6)
  double caloriesPer100;
  @HiveField(7)
  double proteinPer100;
  @HiveField(8)
  double fatPer100;
  @HiveField(9)
  double carbsPer100;
  @HiveField(10)
  double quantity;
  @HiveField(11)
  String unit;
  @HiveField(12)
  DateTime updatedAt;

  MealPlanEntryDBO({
    required this.id,
    required this.planDate,
    required this.dayMealId,
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

  factory MealPlanEntryDBO.fromEntity(MealPlanEntryEntity entity) {
    return MealPlanEntryDBO(
      id: entity.id,
      planDate: entity.planDate,
      dayMealId: entity.dayMealId,
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

  factory MealPlanEntryDBO.fromJson(Map<String, dynamic> json) =>
      _$MealPlanEntryDBOFromJson(json);

  Map<String, dynamic> toJson() => _$MealPlanEntryDBOToJson(this);
}
