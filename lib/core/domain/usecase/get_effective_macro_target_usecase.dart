import 'package:opennutritracker/core/data/repository/macro_target_repository.dart';
import 'package:opennutritracker/core/data/repository/weekly_macro_target_repository.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';
import 'package:opennutritracker/core/utils/meal_plan_utils.dart';

class GetEffectiveMacroTargetUsecase {
  final MacroTargetRepository _macroTargetRepository;
  final WeeklyMacroTargetRepository _weeklyMacroTargetRepository;

  GetEffectiveMacroTargetUsecase(
    this._macroTargetRepository,
    this._weeklyMacroTargetRepository,
  );

  Future<EffectiveMacroTarget> execute(String targetDate) async {
    final override =
        await _macroTargetRepository.getByTargetDate(targetDate);
    final dayOfWeek = dayOfWeekFromDateString(targetDate);
    final weekly =
        await _weeklyMacroTargetRepository.getByDayOfWeek(dayOfWeek);
    return resolveEffectiveMacroTarget(
      date: targetDate,
      override: override,
      weekly: weekly,
    );
  }
}
