import 'package:opennutritracker/core/data/repository/macro_target_repository.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class GetDailyMacroTargetUsecase {
  final MacroTargetRepository _repository;

  GetDailyMacroTargetUsecase(this._repository);

  Future<MacroTargetEntity?> getByTargetDate(String targetDate) =>
      _repository.getByTargetDate(targetDate);
}

class SaveDailyMacroTargetUsecase {
  final MacroTargetRepository _repository;
  final SyncService _syncService;

  SaveDailyMacroTargetUsecase(this._repository, this._syncService);

  Future<void> save(MacroTargetEntity target) async {
    await _repository.upsert(target);
    await _syncService.enqueueMacroTargetUpsert(target);
  }

  Future<void> delete(String id) async {
    await _repository.deleteById(id);
    await _syncService.enqueueMacroTargetDelete(id);
  }
}
