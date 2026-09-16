import 'package:opennutritracker/core/data/repository/water_intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/water_intake_entity.dart';
import 'package:opennutritracker/core/sync/sync_enqueue_extensions.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class AddWaterIntakeUsecase {
  final WaterIntakeRepository _waterIntakeRepository;
  final SyncService _syncService;

  AddWaterIntakeUsecase(this._waterIntakeRepository, this._syncService);

  Future<void> addEntry(WaterIntakeEntity entry) async {
    await _waterIntakeRepository.addEntry(entry);
    await _syncService.enqueueWaterIntakeUpsert(entry);
  }
}
