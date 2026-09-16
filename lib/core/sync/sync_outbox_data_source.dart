import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/sync/sync_operation.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:uuid/uuid.dart';

/// Persists pending sync mutations as JSON strings in an encrypted Hive box.
///
/// Uses [Box]<[String]> so no new Hive type adapter / build_runner step is
/// required. The box is global (not per-profile): each operation carries its
/// own resource id, and the active profile's local DB is the payload source
/// when the worker drains the queue.
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

  /// Enqueues an upsert. If a prior pending upsert/delete for the same
  /// resource id exists, it is replaced so the queue stays compact.
  Future<SyncOperation> enqueueUpsert({
    required SyncResource resource,
    required String resourceId,
    required Map<String, dynamic> payload,
  }) {
    return _enqueue(
      resource: resource,
      resourceId: resourceId,
      mutation: SyncMutation.upsert,
      payload: payload,
    );
  }

  Future<SyncOperation> enqueueDelete({
    required SyncResource resource,
    required String resourceId,
  }) {
    return _enqueue(
      resource: resource,
      resourceId: resourceId,
      mutation: SyncMutation.delete,
      payload: null,
    );
  }

  Future<SyncOperation> _enqueue({
    required SyncResource resource,
    required String resourceId,
    required SyncMutation mutation,
    required Map<String, dynamic>? payload,
  }) async {
    await open();
    final box = _requireBox;

    // Collapse prior ops for the same resource so offline edits do not
    // accumulate redundant PUTs.
    final toRemove = <String>[];
    for (final entry in box.toMap().entries) {
      final op = SyncOperation.fromJson(
        jsonDecode(entry.value) as Map<String, dynamic>,
      );
      if (op.resource == resource && op.resourceId == resourceId) {
        toRemove.add(entry.key);
      }
    }
    for (final key in toRemove) {
      await box.delete(key);
    }

    final op = SyncOperation(
      id: _uuid.v4(),
      resource: resource,
      mutation: mutation,
      resourceId: resourceId,
      payload: payload,
      enqueuedAt: DateTime.now().toUtc(),
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

  Future<void> clear() async {
    await open();
    await _requireBox.clear();
  }
}
