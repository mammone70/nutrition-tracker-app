import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

/// No-op [SyncService] for unit tests that construct write use cases.
class FakeSyncService extends Fake implements SyncService {
  @override
  Future<void> enqueueIntakeUpsert(IntakeEntity intake) async {}

  @override
  Future<void> enqueueIntakeDelete(String intakeId) async {}

  @override
  Future<void> enqueueWeightUpsert(WeightLogEntity entry) async {}

  @override
  Future<void> enqueueWeightDelete(DateTime date) async {}

  @override
  Future<void> enqueueActivityUpsert(Object _) async {}

  @override
  Future<void> enqueueActivityDelete(String _) async {}

  @override
  Future<void> enqueueWaterIntakeUpsert(Object _) async {}

  @override
  Future<void> enqueueWaterIntakeDelete(String _) async {}

  @override
  Future<void> enqueueUserUpsert(Object _) async {}
}
