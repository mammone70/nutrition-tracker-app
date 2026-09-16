import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/sync/sync_enqueue_extensions.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

class DeleteUserActivityUsecase {
  final UserActivityRepository _userActivityRepository;
  final ConfigRepository _configRepository;
  final SyncService _syncService;

  DeleteUserActivityUsecase(
    this._userActivityRepository,
    this._configRepository,
    this._syncService,
  );

  Future<void> deleteUserActivity(UserActivityEntity activityEntity) async {
    await _userActivityRepository.deleteUserActivity(activityEntity);
    await _syncService.enqueueActivityDelete(activityEntity.id);
    final externalId = activityEntity.externalId;
    if (externalId != null) {
      // The importer dedupes against the activities on file, and its window
      // deliberately overlaps the last one — so a deleted workout would be
      // read again and filed again. Remember that this record is unwanted.
      //
      // The activity's date is the workout's own start time, which is what
      // lets the tombstone be dropped once that workout falls outside any
      // window a future import will ask for (#768).
      await _configRepository.addConfigHealthDeletedWorkout(
        externalId,
        activityEntity.date,
      );
    }
  }
}
