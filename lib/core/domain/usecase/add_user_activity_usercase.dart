import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/sync/sync_enqueue_extensions.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class AddUserActivityUsecase {
  final UserActivityRepository _userActivityRepository;
  final SyncService _syncService;

  AddUserActivityUsecase(this._userActivityRepository, this._syncService);

  Future<void> addUserActivity(UserActivityEntity userActivityEntity) async {
    await _userActivityRepository.addUserActivity(userActivityEntity);
    await _syncService.enqueueActivityUpsert(userActivityEntity);
  }
}
