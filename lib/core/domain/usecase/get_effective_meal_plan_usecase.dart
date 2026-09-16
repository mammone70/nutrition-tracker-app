import 'package:opennutritracker/core/data/repository/day_meal_repository.dart';
import 'package:opennutritracker/core/data/repository/meal_plan_entry_repository.dart';
import 'package:opennutritracker/core/data/repository/weekly_meal_plan_entry_repository.dart';
import 'package:opennutritracker/core/data/repository/weekly_meal_repository.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/utils/meal_plan_utils.dart';

class GetEffectiveMealPlanUsecase {
  final DayMealRepository _dayMealRepository;
  final MealPlanEntryRepository _mealPlanEntryRepository;
  final WeeklyMealRepository _weeklyMealRepository;
  final WeeklyMealPlanEntryRepository _weeklyMealPlanEntryRepository;

  GetEffectiveMealPlanUsecase(
    this._dayMealRepository,
    this._mealPlanEntryRepository,
    this._weeklyMealRepository,
    this._weeklyMealPlanEntryRepository,
  );

  Future<EffectiveMealPlan> execute(String planDate) async {
    final dayMeals = await _dayMealRepository.getByPlanDate(planDate);
    final dateEntries =
        await _mealPlanEntryRepository.getByPlanDate(planDate);
    final dayOfWeek = dayOfWeekFromDateString(planDate);
    final weeklyMeals =
        await _weeklyMealRepository.getByDayOfWeek(dayOfWeek);
    final weeklyEntries = await _weeklyMealPlanEntryRepository
        .getByWeeklyMealIds(weeklyMeals.map((m) => m.id).toSet());
    return resolveEffectiveMealPlan(
      date: planDate,
      dayMeals: dayMeals,
      dateEntries: dateEntries,
      weeklyMeals: weeklyMeals,
      weeklyEntries: weeklyEntries,
    );
  }
}
