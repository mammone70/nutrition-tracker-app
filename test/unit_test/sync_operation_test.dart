import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/sync/sync_operation.dart';

void main() {
  test('SyncOperation round-trips through JSON and push mutation shape', () {
    final op = SyncOperation(
      id: 'op-1',
      entityType: SyncEntityType.foodLogEntries,
      action: SyncAction.create,
      entityId: '11111111-1111-4111-8111-111111111111',
      payload: {'quantity': 100.0, 'unit': 'g'},
      clientUpdatedAt: DateTime.utc(2026, 9, 16, 12),
      enqueuedAt: DateTime.utc(2026, 9, 16, 12),
      attempts: 2,
      lastError: 'timeout',
    );

    final restored = SyncOperation.fromJson(op.toJson());
    expect(restored.entityType, SyncEntityType.foodLogEntries);
    expect(restored.action, SyncAction.create);
    expect(restored.entityId, op.entityId);
    expect(restored.payload?['unit'], 'g');

    final push = op.toPushMutation();
    expect(push['entityType'], 'food_log_entries');
    expect(push['action'], 'create');
    expect(push['entityId'], op.entityId);
    expect(push['clientUpdatedAt'], '2026-09-16T12:00:00.000Z');
  });

  test('bodyWeight is excluded from sync-push entity set', () {
    expect(SyncEntityType.bodyWeight.isSyncPushEntity, isFalse);
    expect(SyncEntityType.foods.isSyncPushEntity, isTrue);
  });
}
