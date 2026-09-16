import 'package:opennutritracker/core/data/repository/weekly_macro_target_repository.dart';
import 'package:opennutritracker/core/domain/entity/weekly_macro_target_entity.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class GetWeeklyMacroTargetsUsecase {
  final WeeklyMacroTargetRepository _repository;

  GetWeeklyMacroTargetsUsecase(this._repository);

  Future<List<WeeklyMacroTargetEntity>> getAll() => _repository.getAll();

  Future<WeeklyMacroTargetEntity?> getByDayOfWeek(int dayOfWeek) =>
      _repository.getByDayOfWeek(dayOfWeek);
}

class SaveWeeklyMacroTargetsUsecase {
  final WeeklyMacroTargetRepository _repository;
  final SyncService _syncService;

  SaveWeeklyMacroTargetsUsecase(this._repository, this._syncService);

  Future<void> saveAll(List<WeeklyMacroTargetEntity> targets) async {
    for (final target in targets) {
      await _repository.upsert(target);
      await _syncService.enqueueWeeklyMacroTargetUpsert(target);
    }
  }

  Future<void> save(WeeklyMacroTargetEntity target) async {
    await _repository.upsert(target);
    await _syncService.enqueueWeeklyMacroTargetUpsert(target);
  }
}
