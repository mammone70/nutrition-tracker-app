import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/sync/sync_enqueue_extensions.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class AddIntakeUsecase {
  final IntakeRepository _intakeRepository;
  final SyncService _syncService;

  AddIntakeUsecase(this._intakeRepository, this._syncService);

  Future<void> addIntake(IntakeEntity intakeEntity) async {
    await _intakeRepository.addIntake(intakeEntity);
    await _syncService.enqueueIntakeUpsert(intakeEntity);
  }
}
