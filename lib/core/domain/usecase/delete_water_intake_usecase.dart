import 'package:opennutritracker/core/data/repository/water_intake_repository.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class DeleteWaterIntakeUsecase {
  final WaterIntakeRepository _waterIntakeRepository;
  final SyncService _syncService;

  DeleteWaterIntakeUsecase(this._waterIntakeRepository, this._syncService);

  Future<void> deleteEntry(String id) async {
    await _waterIntakeRepository.deleteEntry(id);
    await _syncService.enqueueWaterIntakeDelete(id);
  }
}
