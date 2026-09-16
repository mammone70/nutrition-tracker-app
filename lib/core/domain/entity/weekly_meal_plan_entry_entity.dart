import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/weekly_meal_plan_entry_dbo.dart';

class WeeklyMealPlanEntryEntity extends Equatable {
  final String id;
  final String weeklyMealId;
  final String foodId;
  final String foodName;
  final String? brand;
  final double caloriesPer100;
  final double proteinPer100;
  final double fatPer100;
  final double carbsPer100;
  final double quantity;
  final String unit;
  final DateTime updatedAt;

  const WeeklyMealPlanEntryEntity({
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

  factory WeeklyMealPlanEntryEntity.fromDBO(WeeklyMealPlanEntryDBO dbo) {
    return WeeklyMealPlanEntryEntity(
      id: dbo.id,
      weeklyMealId: dbo.weeklyMealId,
      foodId: dbo.foodId,
      foodName: dbo.foodName,
      brand: dbo.brand,
      caloriesPer100: dbo.caloriesPer100,
      proteinPer100: dbo.proteinPer100,
      fatPer100: dbo.fatPer100,
      carbsPer100: dbo.carbsPer100,
      quantity: dbo.quantity,
      unit: dbo.unit,
      updatedAt: dbo.updatedAt,
    );
  }

  double get calories => caloriesPer100 * quantity / 100;
  double get proteinG => proteinPer100 * quantity / 100;
  double get fatG => fatPer100 * quantity / 100;
  double get carbsG => carbsPer100 * quantity / 100;

  @override
  List<Object?> get props => [
    id,
    weeklyMealId,
    foodId,
    foodName,
    brand,
    caloriesPer100,
    proteinPer100,
    fatPer100,
    carbsPer100,
    quantity,
    unit,
    updatedAt,
  ];
}
