import 'package:opennutritracker/core/data/repository/waist_log_repository.dart';
import 'package:opennutritracker/core/domain/entity/waist_log_entity.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class AddWaistLogUsecase {
  final WaistLogRepository _repository;
  final SyncService _syncService;

  AddWaistLogUsecase(this._repository, this._syncService);

  Future<void> addEntry(WaistLogEntity entry) async {
    await _repository.addEntry(entry);
    await _syncService.enqueueWaistLogUpsert(entry);
  }
}

class GetWaistLogUsecase {
  final WaistLogRepository _repository;

  GetWaistLogUsecase(this._repository);

  Future<List<WaistLogEntity>> getAllEntries() => _repository.getAllEntries();

  Future<List<WaistLogEntity>> getEntriesInRange(DateTime from, DateTime to) =>
      _repository.getEntriesInRange(from, to);

  Future<WaistLogEntity?> getEntry(DateTime date) =>
      _repository.getEntry(date);
}

class DeleteWaistLogUsecase {
  final WaistLogRepository _repository;
  final SyncService _syncService;

  DeleteWaistLogUsecase(this._repository, this._syncService);

  Future<void> deleteEntry(DateTime date) async {
    await _repository.deleteEntry(date);
    await _syncService.enqueueWaistLogDelete(date);
  }
}
