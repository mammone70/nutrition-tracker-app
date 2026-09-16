import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/meal_plan_entry_dbo.dart';

class MealPlanEntryEntity extends Equatable {
  final String id;
  final String planDate;
  final String dayMealId;
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

  const MealPlanEntryEntity({
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

  factory MealPlanEntryEntity.fromDBO(MealPlanEntryDBO dbo) {
    return MealPlanEntryEntity(
      id: dbo.id,
      planDate: dbo.planDate,
      dayMealId: dbo.dayMealId,
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
    planDate,
    dayMealId,
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

enum MealPlanSource { override, weekly, none }

class MealPlanFoodEntry extends Equatable {
  final String id;
  final String foodId;
  final String foodName;
  final String? brand;
  final double caloriesPer100;
  final double proteinPer100;
  final double fatPer100;
  final double carbsPer100;
  final double quantity;
  final String unit;

  const MealPlanFoodEntry({
    required this.id,
    required this.foodId,
    required this.foodName,
    this.brand,
    required this.caloriesPer100,
    required this.proteinPer100,
    required this.fatPer100,
    required this.carbsPer100,
    required this.quantity,
    required this.unit,
  });

  double get calories => caloriesPer100 * quantity / 100;
  double get proteinG => proteinPer100 * quantity / 100;
  double get fatG => fatPer100 * quantity / 100;
  double get carbsG => carbsPer100 * quantity / 100;

  @override
  List<Object?> get props => [
    id,
    foodId,
    foodName,
    brand,
    caloriesPer100,
    proteinPer100,
    fatPer100,
    carbsPer100,
    quantity,
    unit,
  ];
}

class EffectiveMealBlock extends Equatable {
  final String id;
  final int mealIndex;
  final String name;
  final String? mealTime;
  final MealPlanSource source;
  final List<MealPlanFoodEntry> entries;

  const EffectiveMealBlock({
    required this.id,
    required this.mealIndex,
    required this.name,
    this.mealTime,
    required this.source,
    required this.entries,
  });

  @override
  List<Object?> get props => [id, mealIndex, name, mealTime, source, entries];
}

class EffectiveMealPlan extends Equatable {
  final MealPlanSource source;
  final List<EffectiveMealBlock> meals;

  const EffectiveMealPlan({required this.source, required this.meals});

  @override
  List<Object?> get props => [source, meals];
}
