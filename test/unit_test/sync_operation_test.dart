import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/sync/sync_operation.dart';

void main() {
  test('SyncOperation round-trips through JSON', () {
    final op = SyncOperation(
      id: 'op-1',
      resource: SyncResource.intake,
      mutation: SyncMutation.upsert,
      resourceId: 'intake-1',
      payload: {'id': 'intake-1', 'amount': 100.0},
      enqueuedAt: DateTime.utc(2026, 9, 16, 12),
      attempts: 2,
      lastError: 'timeout',
    );

    final restored = SyncOperation.fromJson(op.toJson());
    expect(restored.id, op.id);
    expect(restored.resource, SyncResource.intake);
    expect(restored.mutation, SyncMutation.upsert);
    expect(restored.resourceId, 'intake-1');
    expect(restored.payload?['amount'], 100.0);
    expect(restored.attempts, 2);
    expect(restored.lastError, 'timeout');
  });

  test('copyWith updates attempts and clears error when omitted as null', () {
    final op = SyncOperation(
      id: 'op-2',
      resource: SyncResource.activity,
      mutation: SyncMutation.delete,
      resourceId: 'act-1',
      enqueuedAt: DateTime.utc(2026, 9, 16),
      attempts: 1,
      lastError: 'boom',
    );
    final next = op.copyWith(attempts: 2, lastError: null);
    expect(next.attempts, 2);
    expect(next.lastError, isNull);
    expect(next.resource, SyncResource.activity);
  });
}
