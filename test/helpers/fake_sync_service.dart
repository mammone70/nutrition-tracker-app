import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/sync/sync_operation.dart';
import 'package:opennutritracker/core/sync/sync_service.dart';

/// No-op [SyncService] for unit tests that construct write use cases.
///
/// Enqueue calls succeed without touching Hive or the network.
class FakeSyncService extends Fake implements SyncService {
  @override
  Future<void> enqueueUpsert({
    required SyncResource resource,
    required String resourceId,
    required Map<String, dynamic> payload,
  }) async {}

  @override
  Future<void> enqueueDelete({
    required SyncResource resource,
    required String resourceId,
  }) async {}
}
