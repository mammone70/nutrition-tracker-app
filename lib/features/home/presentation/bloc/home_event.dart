part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadItemsEvent extends HomeEvent {
  /// When set, [HomeLoadedState.confirmedToDiaryCount] carries this value so
  /// the UI can show a confirmation snack after a meal-plan confirm action.
  final int? confirmedToDiaryCount;

  const LoadItemsEvent({this.confirmedToDiaryCount});

  @override
  List<Object?> get props => [confirmedToDiaryCount];
}

class ConfirmMealPlanFoodEvent extends HomeEvent {
  final MealPlanFoodEntry food;
  final EffectiveMealBlock meal;

  const ConfirmMealPlanFoodEvent({required this.food, required this.meal});

  @override
  List<Object?> get props => [food, meal];
}

class ConfirmMealPlanMealEvent extends HomeEvent {
  final EffectiveMealBlock meal;

  const ConfirmMealPlanMealEvent({required this.meal});

  @override
  List<Object?> get props => [meal];
}

class ConfirmMealPlanDayEvent extends HomeEvent {
  const ConfirmMealPlanDayEvent();
}

class UpdateMealPlanFoodQuantityEvent extends HomeEvent {
  final int mealIndex;
  final String entryId;
  final String foodId;
  final double quantity;

  const UpdateMealPlanFoodQuantityEvent({
    required this.mealIndex,
    required this.entryId,
    required this.foodId,
    required this.quantity,
  });

  @override
  List<Object?> get props => [mealIndex, entryId, foodId, quantity];
}

class DeleteMealPlanFoodEvent extends HomeEvent {
  final int mealIndex;
  final String entryId;
  final String foodId;

  const DeleteMealPlanFoodEvent({
    required this.mealIndex,
    required this.entryId,
    required this.foodId,
  });

  @override
  List<Object?> get props => [mealIndex, entryId, foodId];
}

class AddMealPlanFoodEvent extends HomeEvent {
  final int mealIndex;
  final String mealId;
  final String mealName;
  final String? mealTime;
  final MealPlanFoodEntry food;

  const AddMealPlanFoodEvent({
    required this.mealIndex,
    required this.mealId,
    required this.mealName,
    this.mealTime,
    required this.food,
  });

  @override
  List<Object?> get props => [mealIndex, mealId, mealName, mealTime, food];
}
