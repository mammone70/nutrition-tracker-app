import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/water_intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/sync/sync_operation.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';
import 'package:opennutritracker/core/utils/extensions.dart';

/// Thin helpers so use cases can enqueue sync work without knowing DBO JSON.
extension SyncServiceEnqueue on SyncService {
  Future<void> enqueueIntakeUpsert(IntakeEntity entity) {
    return enqueueUpsert(
      resource: SyncResource.intake,
      resourceId: entity.id,
      payload: IntakeDBO.fromIntakeEntity(entity).toJson(),
    );
  }

  Future<void> enqueueIntakeDelete(String intakeId) {
    return enqueueDelete(
      resource: SyncResource.intake,
      resourceId: intakeId,
    );
  }

  Future<void> enqueueActivityUpsert(UserActivityEntity entity) {
    return enqueueUpsert(
      resource: SyncResource.activity,
      resourceId: entity.id,
      payload: UserActivityDBO.fromUserActivityEntity(entity).toJson(),
    );
  }

  Future<void> enqueueActivityDelete(String activityId) {
    return enqueueDelete(
      resource: SyncResource.activity,
      resourceId: activityId,
    );
  }

  Future<void> enqueueTrackedDayUpsert(TrackedDayDBO dbo) {
    return enqueueUpsert(
      resource: SyncResource.trackedDay,
      resourceId: dbo.day.toParsedDay(),
      payload: dbo.toJson(),
    );
  }

  Future<void> enqueueWeightLogUpsert(WeightLogEntity entity) {
    return enqueueUpsert(
      resource: SyncResource.weightLog,
      resourceId: entity.date.toParsedDay(),
      payload: WeightLogDBO.fromWeightLogEntity(entity).toJson(),
    );
  }

  Future<void> enqueueWeightLogDelete(DateTime date) {
    return enqueueDelete(
      resource: SyncResource.weightLog,
      resourceId: date.toParsedDay(),
    );
  }

  Future<void> enqueueWaterIntakeUpsert(WaterIntakeEntity entity) {
    return enqueueUpsert(
      resource: SyncResource.waterIntake,
      resourceId: entity.id,
      payload: WaterIntakeDBO.fromWaterIntakeEntity(entity).toJson(),
    );
  }

  Future<void> enqueueWaterIntakeDelete(String id) {
    return enqueueDelete(
      resource: SyncResource.waterIntake,
      resourceId: id,
    );
  }

  Future<void> enqueueUserUpsert(UserEntity entity) {
    return enqueueUpsert(
      resource: SyncResource.user,
      resourceId: 'user',
      payload: UserDBO.fromUserEntity(entity).toJson(),
    );
  }
}
