import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/day_meal_dbo.dart';

class DayMealEntity extends Equatable {
  final String id;
  final String planDate;
  final int mealIndex;
  final String name;
  final String? mealTime;
  final DateTime updatedAt;

  const DayMealEntity({
    required this.id,
    required this.planDate,
    required this.mealIndex,
    required this.name,
    this.mealTime,
    required this.updatedAt,
  });

  factory DayMealEntity.fromDBO(DayMealDBO dbo) {
    return DayMealEntity(
      id: dbo.id,
      planDate: dbo.planDate,
      mealIndex: dbo.mealIndex,
      name: dbo.name,
      mealTime: dbo.mealTime,
      updatedAt: dbo.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    planDate,
    mealIndex,
    name,
    mealTime,
    updatedAt,
  ];
}
