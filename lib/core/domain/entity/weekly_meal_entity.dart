import 'package:equatable/equatable.dart';
import 'package:opennutritracker/core/data/dbo/weekly_meal_dbo.dart';

class WeeklyMealEntity extends Equatable {
  final String id;
  final int dayOfWeek;
  final int mealIndex;
  final String name;
  final String? mealTime;
  final DateTime updatedAt;

  const WeeklyMealEntity({
    required this.id,
    required this.dayOfWeek,
    required this.mealIndex,
    required this.name,
    this.mealTime,
    required this.updatedAt,
  });

  factory WeeklyMealEntity.fromDBO(WeeklyMealDBO dbo) {
    return WeeklyMealEntity(
      id: dbo.id,
      dayOfWeek: dbo.dayOfWeek,
      mealIndex: dbo.mealIndex,
      name: dbo.name,
      mealTime: dbo.mealTime,
      updatedAt: dbo.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    dayOfWeek,
    mealIndex,
    name,
    mealTime,
    updatedAt,
  ];
}
