import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class DeleteIntakeUsecase {
  final IntakeRepository _intakeRepository;
  final SyncService _syncService;

  DeleteIntakeUsecase(this._intakeRepository, this._syncService);

  Future<void> deleteIntake(IntakeEntity intakeEntity) async {
    await _intakeRepository.deleteIntake(intakeEntity);
    await _syncService.enqueueIntakeDelete(intakeEntity.id);
  }
}
