import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/water_intake_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_api_client.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_sync_credentials.dart';
import 'package:opennutritracker/core/sync/sync_operation.dart';
import 'package:opennutritracker/core/sync/sync_outbox_data_source.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:synchronized/synchronized.dart';

/// Local-first sync coordinator.
///
/// Write path: callers persist to Hive first, then [enqueueUpsert] /
/// [enqueueDelete]. This service drains the outbox when online and
/// optionally pulls remote changes into Hive.
///
/// Reads never block on the network — the UI always uses local repositories.
class SyncService extends ChangeNotifier {
  final CalorieTrackerSyncCredentials _credentials;
  final SyncOutboxDataSource _outbox;
  final CalorieTrackerApiClient _api;
  final IntakeRepository _intakeRepository;
  final UserActivityRepository _activityRepository;
  final TrackedDayRepository _trackedDayRepository;
  final WeightLogRepository _weightLogRepository;
  final WaterIntakeRepository _waterIntakeRepository;
  final UserRepository _userRepository;

  final _log = Logger('SyncService');
  final _lock = Lock();

  bool _syncing = false;
  String? _lastError;
  DateTime? _lastSyncAt;
  int _pendingCount = 0;

  SyncService({
    required CalorieTrackerSyncCredentials credentials,
    required SyncOutboxDataSource outbox,
    required CalorieTrackerApiClient api,
    required IntakeRepository intakeRepository,
    required UserActivityRepository activityRepository,
    required TrackedDayRepository trackedDayRepository,
    required WeightLogRepository weightLogRepository,
    required WaterIntakeRepository waterIntakeRepository,
    required UserRepository userRepository,
  })  : _credentials = credentials,
        _outbox = outbox,
        _api = api,
        _intakeRepository = intakeRepository,
        _activityRepository = activityRepository,
        _trackedDayRepository = trackedDayRepository,
        _weightLogRepository = weightLogRepository,
        _waterIntakeRepository = waterIntakeRepository,
        _userRepository = userRepository;

  bool get isSyncing => _syncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncAt => _lastSyncAt;
  int get pendingCount => _pendingCount;

  Future<void> refreshPendingCount() async {
    _pendingCount = await _outbox.pendingCount();
    notifyListeners();
  }

  Future<void> enqueueUpsert({
    required SyncResource resource,
    required String resourceId,
    required Map<String, dynamic> payload,
  }) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueueUpsert(
      resource: resource,
      resourceId: resourceId,
      payload: payload,
    );
    await refreshPendingCount();
    // Fire-and-forget drain; failures stay in the outbox.
    unawaited(syncNow());
  }

  Future<void> enqueueDelete({
    required SyncResource resource,
    required String resourceId,
  }) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueueDelete(
      resource: resource,
      resourceId: resourceId,
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  /// Pushes the outbox, then pulls remote changes since the last successful
  /// pull. No-op when sync is disabled or not configured.
  Future<bool> syncNow({bool pull = true}) async {
    if (!await _credentials.isConfigured()) return false;
    return _lock.synchronized(() async {
      if (_syncing) return false;
      _syncing = true;
      _lastError = null;
      notifyListeners();
      try {
        await _pushOutbox();
        if (pull) {
          await _pullRemote();
        }
        _lastSyncAt = DateTime.now().toUtc();
        await refreshPendingCount();
        return true;
      } catch (error, stackTrace) {
        _log.warning('Sync failed', error, stackTrace);
        _lastError = error.toString();
        await refreshPendingCount();
        return false;
      } finally {
        _syncing = false;
        notifyListeners();
      }
    });
  }

  Future<void> _pushOutbox() async {
    final pending = await _outbox.getAll();
    for (final op in pending) {
      try {
        await _api.apply(op);
        await _outbox.remove(op.id);
      } catch (error) {
        final updated = op.copyWith(
          attempts: op.attempts + 1,
          lastError: error.toString(),
        );
        await _outbox.update(updated);
        // Stop on first failure so ordering is preserved; later ops may
        // depend on earlier creates.
        rethrow;
      }
    }
  }

  Future<void> _pullRemote() async {
    final since = await _credentials.getLastPullAt();
    final remote = await _api.pullSince(since);

    for (final entry in remote.entries) {
      switch (entry.key) {
        case SyncResource.intake:
          await _mergeIntakes(entry.value);
        case SyncResource.activity:
          await _mergeActivities(entry.value);
        case SyncResource.trackedDay:
          await _mergeTrackedDays(entry.value);
        case SyncResource.weightLog:
          await _mergeWeightLogs(entry.value);
        case SyncResource.waterIntake:
          await _mergeWaterIntakes(entry.value);
        case SyncResource.user:
          await _mergeUser(entry.value);
      }
    }

    await _credentials.setLastPullAt(DateTime.now().toUtc());
  }

  Future<void> _mergeIntakes(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final dbos = items.map(IntakeDBO.fromJson).toList();
    // addAll overwrites by Hive key (intake id) — last write from remote wins
    // for records not currently pending in the outbox.
    final pendingIds = await _pendingResourceIds(SyncResource.intake);
    final toApply =
        dbos.where((dbo) => !pendingIds.contains(dbo.id)).toList();
    if (toApply.isNotEmpty) {
      await _intakeRepository.addAllIntakeDBOs(toApply);
    }
  }

  Future<void> _mergeActivities(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final dbos = items.map(UserActivityDBO.fromJson).toList();
    final pendingIds = await _pendingResourceIds(SyncResource.activity);
    final toApply =
        dbos.where((dbo) => !pendingIds.contains(dbo.id)).toList();
    if (toApply.isNotEmpty) {
      await _activityRepository.addAllUserActivityDBOs(toApply);
    }
  }

  Future<void> _mergeTrackedDays(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final dbos = items.map(TrackedDayDBO.fromJson).toList();
    final pendingIds = await _pendingResourceIds(SyncResource.trackedDay);
    final toApply = dbos
        .where((dbo) => !pendingIds.contains(dbo.day.toParsedDay()))
        .toList();
    if (toApply.isNotEmpty) {
      await _trackedDayRepository.addAllTrackedDays(toApply);
    }
  }

  Future<void> _mergeWeightLogs(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final dbos = items.map(WeightLogDBO.fromJson).toList();
    final pendingIds = await _pendingResourceIds(SyncResource.weightLog);
    final toApply = dbos
        .where((dbo) => !pendingIds.contains(dbo.date.toParsedDay()))
        .toList();
    if (toApply.isNotEmpty) {
      await _weightLogRepository.addAllEntries(toApply);
    }
  }

  Future<void> _mergeWaterIntakes(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final dbos = items.map(WaterIntakeDBO.fromJson).toList();
    final pendingIds = await _pendingResourceIds(SyncResource.waterIntake);
    final toApply =
        dbos.where((dbo) => !pendingIds.contains(dbo.id)).toList();
    if (toApply.isNotEmpty) {
      await _waterIntakeRepository.addAllEntries(toApply);
    }
  }

  Future<void> _mergeUser(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final pendingIds = await _pendingResourceIds(SyncResource.user);
    if (pendingIds.contains('user')) return;
    final dbo = UserDBO.fromJson(items.first);
    await _userRepository.updateUserDataFromDBO(dbo);
  }

  Future<Set<String>> _pendingResourceIds(SyncResource resource) async {
    final ops = await _outbox.getAll();
    return ops
        .where((op) => op.resource == resource)
        .map((op) => op.resourceId)
        .toSet();
  }
}
