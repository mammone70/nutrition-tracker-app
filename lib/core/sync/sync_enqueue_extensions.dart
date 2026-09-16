import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

/// Aliases matching the names use cases already call.
extension SyncServiceEnqueue on SyncService {
  Future<void> enqueueWeightLogUpsert(WeightLogEntity entity) =>
      enqueueWeightUpsert(entity);

  Future<void> enqueueWeightLogDelete(DateTime date) =>
      enqueueWeightDelete(date);
}
