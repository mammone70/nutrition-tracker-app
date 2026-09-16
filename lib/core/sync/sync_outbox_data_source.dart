import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/sync/sync_operation.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:uuid/uuid.dart';

/// Persists pending sync mutations as JSON in an encrypted Hive box.
class SyncOutboxDataSource {
  static const boxName = 'SyncOutboxBox';

  final HiveDBProvider _hive;
  final Uuid _uuid;

  SyncOutboxDataSource(this._hive, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Box<String>? _box;

  Future<void> open() async {
    if (_box != null && _box!.isOpen) return;
    _box = await _hive.openScopedBox<String>(boxName, '');
  }

  Box<String> get _requireBox {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('Sync outbox box is not open.');
    }
    return box;
  }

  Future<List<SyncOperation>> getAll() async {
    await open();
    final ops = _requireBox.values
        .map((raw) => SyncOperation.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            ))
        .toList();
    ops.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
    return ops;
  }

  Future<int> pendingCount() async {
    await open();
    return _requireBox.length;
  }

  Future<SyncOperation> enqueue({
    required SyncEntityType entityType,
    required SyncAction action,
    required String entityId,
    Map<String, dynamic>? payload,
  }) async {
    await open();
    final box = _requireBox;

    // Collapse prior ops for the same entity so offline edits stay compact.
    final toRemove = <String>[];
    for (final entry in box.toMap().entries) {
      final op = SyncOperation.fromJson(
        jsonDecode(entry.value) as Map<String, dynamic>,
      );
      if (op.entityType == entityType && op.entityId == entityId) {
        toRemove.add(entry.key);
      }
    }
    for (final key in toRemove) {
      await box.delete(key);
    }

    final now = DateTime.now().toUtc();
    final op = SyncOperation(
      id: _uuid.v4(),
      entityType: entityType,
      action: action,
      entityId: entityId,
      payload: payload,
      clientUpdatedAt: now,
      enqueuedAt: now,
    );
    await box.put(op.id, jsonEncode(op.toJson()));
    return op;
  }

  Future<void> update(SyncOperation operation) async {
    await open();
    await _requireBox.put(operation.id, jsonEncode(operation.toJson()));
  }

  Future<void> remove(String operationId) async {
    await open();
    await _requireBox.delete(operationId);
  }

  Future<void> removeAll(Iterable<String> operationIds) async {
    await open();
    for (final id in operationIds) {
      await _requireBox.delete(id);
    }
  }

  Future<void> clear() async {
    await open();
    await _requireBox.clear();
  }
}
