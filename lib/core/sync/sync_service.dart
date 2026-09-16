import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_api_client.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_sync_credentials.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_sync_mapper.dart';
import 'package:opennutritracker/core/sync/sync_operation.dart';
import 'package:opennutritracker/core/sync/sync_outbox_data_source.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:synchronized/synchronized.dart';

/// Local-first sync coordinator for mammone70/calorie-tracker.
///
/// Writes go to Hive first; this service queues API mutations and drains them
/// through `POST /api/sync/push` (plus `POST /api/body-weight` for weight).
class SyncService extends ChangeNotifier {
  final CalorieTrackerSyncCredentials _credentials;
  final SyncOutboxDataSource _outbox;
  final CalorieTrackerApiClient _api;
  final IntakeRepository _intakeRepository;

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
  })  : _credentials = credentials,
        _outbox = outbox,
        _api = api,
        _intakeRepository = intakeRepository;

  bool get isSyncing => _syncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncAt => _lastSyncAt;
  int get pendingCount => _pendingCount;

  Future<void> refreshPendingCount() async {
    _pendingCount = await _outbox.pendingCount();
    notifyListeners();
  }

  Future<void> enqueueIntakeUpsert(IntakeEntity intake) async {
    if (!await _credentials.isConfigured()) return;
    final foodId = CalorieTrackerSyncMapper.foodIdForMeal(intake.meal);
    final dayMealId =
        CalorieTrackerSyncMapper.dayMealIdFor(intake.dateTime, intake.type);

    await _outbox.enqueue(
      entityType: SyncEntityType.foods,
      action: SyncAction.create,
      entityId: foodId,
      payload: CalorieTrackerSyncMapper.foodPayload(intake.meal),
    );
    await _outbox.enqueue(
      entityType: SyncEntityType.dayMeals,
      action: SyncAction.create,
      entityId: dayMealId,
      payload: CalorieTrackerSyncMapper.dayMealPayload(
        date: intake.dateTime,
        type: intake.type,
      ),
    );
    await _outbox.enqueue(
      entityType: SyncEntityType.foodLogEntries,
      action: SyncAction.create,
      entityId: intake.id,
      payload: CalorieTrackerSyncMapper.foodLogPayload(
        intake: intake,
        foodId: foodId,
        dayMealId: dayMealId,
      ),
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueIntakeDelete(String intakeId) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.foodLogEntries,
      action: SyncAction.delete,
      entityId: intakeId,
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueWeightUpsert(WeightLogEntity entry) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.bodyWeight,
      action: SyncAction.create,
      entityId: entry.date.toParsedDay(),
      payload: CalorieTrackerSyncMapper.bodyWeightPayload(
        date: entry.date,
        weightKg: entry.weightKg,
        note: entry.note,
      ),
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueWeightDelete(DateTime date) async {
    if (!await _credentials.isConfigured()) return;
    // Body-weight delete needs the remote row id; queue a tombstone keyed by
    // day so a later online sync can resolve via range fetch if needed.
    await _outbox.enqueue(
      entityType: SyncEntityType.bodyWeight,
      action: SyncAction.delete,
      entityId: date.toParsedDay(),
      payload: {'loggedOn': date.toParsedDay()},
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  /// No-op stubs kept so activity/water/user use cases compile; those domains
  /// are not mirrored 1:1 on calorie-tracker yet.
  Future<void> enqueueActivityUpsert(Object _) async {}
  Future<void> enqueueActivityDelete(String _) async {}
  Future<void> enqueueWaterIntakeUpsert(Object _) async {}
  Future<void> enqueueWaterIntakeDelete(String _) async {}
  Future<void> enqueueUserUpsert(Object _) async {}

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
    if (pending.isEmpty) return;

    final syncOps =
        pending.where((op) => op.entityType.isSyncPushEntity).toList();
    final weightOps =
        pending.where((op) => op.entityType == SyncEntityType.bodyWeight).toList();

    if (syncOps.isNotEmpty) {
      // Prefer create→update mapping: collapsing always stores latest action;
      // foods/day_meals use create (upsert-friendly on server with entityId).
      await _api.pushMutations(syncOps);
      await _outbox.removeAll(syncOps.map((op) => op.id));
    }

    for (final op in weightOps) {
      try {
        if (op.action == SyncAction.delete) {
          // Best-effort: without the remote id we skip hard delete for now.
          await _outbox.remove(op.id);
          continue;
        }
        await _api.upsertBodyWeight(op.payload ?? const {});
        await _outbox.remove(op.id);
      } catch (error) {
        await _outbox.update(
          op.copyWith(attempts: op.attempts + 1, lastError: error.toString()),
        );
        rethrow;
      }
    }
  }

  Future<void> _pullRemote() async {
    final since = await _credentials.getLastPullAt();
    final pull = await _api.pullSince(since);
    final logs = (pull['foodLogEntries'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final foods = (pull['foods'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final foodById = {
      for (final f in foods) f['id'] as String: f,
    };

    final pendingIds = (await _outbox.getAll())
        .where((op) => op.entityType == SyncEntityType.foodLogEntries)
        .map((op) => op.entityId)
        .toSet();

    final toApply = <IntakeDBO>[];
    for (final log in logs) {
      final id = log['id'] as String?;
      if (id == null || pendingIds.contains(id)) continue;
      if (log['deletedAt'] != null) {
        // Soft-deleted remotely — drop local copy if present.
        final existing = await _intakeRepository.getIntakeById(id);
        if (existing != null) {
          await _intakeRepository.deleteIntake(existing);
        }
        continue;
      }
      final foodId = log['foodId'] as String?;
      final food = foodId == null ? null : foodById[foodId];
      toApply.add(_intakeFromRemote(log, food));
    }
    if (toApply.isNotEmpty) {
      await _intakeRepository.addAllIntakeDBOs(toApply);
    }

    final serverTime = pull['serverTime'] as String?;
    await _credentials.setLastPullAt(
      serverTime != null
          ? DateTime.parse(serverTime)
          : DateTime.now().toUtc(),
    );
  }

  IntakeDBO _intakeFromRemote(
    Map<String, dynamic> log,
    Map<String, dynamic>? food,
  ) {
    final nutrients = food?['nutrientsPer100g'] as Map<String, dynamic>? ?? {};
    final meal = MealDBO(
      code: food?['externalId'] as String?,
      name: food?['name'] as String? ?? 'Food',
      brands: food?['brand'] as String?,
      thumbnailImageUrl: null,
      mainImageUrl: null,
      url: null,
      mealQuantity: null,
      mealUnit: log['unit'] as String? ?? 'g',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      source: MealSourceDBO.custom,
      nutriments: MealNutrimentsDBO(
        energyKcal100: (nutrients['calories'] as num?)?.toDouble(),
        carbohydrates100: (nutrients['carbs'] as num?)?.toDouble(),
        fat100: (nutrients['fat'] as num?)?.toDouble(),
        proteins100: (nutrients['protein'] as num?)?.toDouble(),
        sugars100: null,
        saturatedFat100: null,
        fiber100: null,
      ),
    );

    return IntakeDBO(
      id: log['id'] as String,
      unit: log['unit'] as String? ?? 'g',
      amount: (log['quantity'] as num).toDouble(),
      type: IntakeTypeDBO.snack,
      meal: meal,
      dateTime: DateTime.parse(log['loggedAt'] as String).toLocal(),
    );
  }
}
