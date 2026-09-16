import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/sync/sync_enqueue_extensions.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class DeleteWeightLogUsecase {
  final WeightLogRepository _weightLogRepository;
  final SyncService _syncService;

  DeleteWeightLogUsecase(this._weightLogRepository, this._syncService);

  Future<void> deleteEntry(DateTime date) async {
    await _weightLogRepository.deleteEntry(date);
    await _syncService.enqueueWeightLogDelete(date);
  }
}
