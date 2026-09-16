import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class UpdateIntakeUsecase {
  final IntakeRepository _intakeRepository;
  final SyncService _syncService;

  UpdateIntakeUsecase(this._intakeRepository, this._syncService);

  Future<IntakeEntity?> updateIntake(
    String intakeId,
    Map<String, dynamic> intakeFields,
  ) async {
    final updated =
        await _intakeRepository.updateIntake(intakeId, intakeFields);
    if (updated != null) {
      await _syncService.enqueueIntakeUpsert(updated);
    }
    return updated;
  }
}
