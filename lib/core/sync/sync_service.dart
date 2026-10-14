import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/repository/day_meal_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/macro_target_repository.dart';
import 'package:opennutritracker/core/data/repository/meal_plan_entry_repository.dart';
import 'package:opennutritracker/core/data/repository/weekly_macro_target_repository.dart';
import 'package:opennutritracker/core/data/repository/weekly_meal_plan_entry_repository.dart';
import 'package:opennutritracker/core/data/repository/weekly_meal_repository.dart';
import 'package:opennutritracker/core/domain/entity/day_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_macro_target_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/weekly_meal_plan_entry_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/core/domain/entity/waist_log_entity.dart';
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
/// Pull applies diary logs **and** daily/weekly meal plans + macro targets.
class SyncService extends ChangeNotifier {
  final CalorieTrackerSyncCredentials _credentials;
  final SyncOutboxDataSource _outbox;
  final CalorieTrackerApiClient _api;
  final IntakeRepository _intakeRepository;
  final DayMealRepository _dayMealRepository;
  final MealPlanEntryRepository _mealPlanEntryRepository;
  final WeeklyMealRepository _weeklyMealRepository;
  final WeeklyMealPlanEntryRepository _weeklyMealPlanEntryRepository;
  final MacroTargetRepository _macroTargetRepository;
  final WeeklyMacroTargetRepository _weeklyMacroTargetRepository;

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
    required DayMealRepository dayMealRepository,
    required MealPlanEntryRepository mealPlanEntryRepository,
    required WeeklyMealRepository weeklyMealRepository,
    required WeeklyMealPlanEntryRepository weeklyMealPlanEntryRepository,
    required MacroTargetRepository macroTargetRepository,
    required WeeklyMacroTargetRepository weeklyMacroTargetRepository,
  }) : _credentials = credentials,
       _outbox = outbox,
       _api = api,
       _intakeRepository = intakeRepository,
       _dayMealRepository = dayMealRepository,
       _mealPlanEntryRepository = mealPlanEntryRepository,
       _weeklyMealRepository = weeklyMealRepository,
       _weeklyMealPlanEntryRepository = weeklyMealPlanEntryRepository,
       _macroTargetRepository = macroTargetRepository,
       _weeklyMacroTargetRepository = weeklyMacroTargetRepository;

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
    final dayMealId = CalorieTrackerSyncMapper.dayMealIdFor(
      intake.dateTime,
      intake.type,
    );

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

  Future<void> enqueueWeightLogUpsert(WeightLogEntity entry) async {
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

  Future<void> enqueueWeightLogDelete(DateTime date) async {
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

  Future<void> enqueueWaistLogUpsert(WaistLogEntity entry) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.waistCircumference,
      action: SyncAction.create,
      entityId: entry.date.toParsedDay(),
      payload: CalorieTrackerSyncMapper.waistCircumferencePayload(
        date: entry.date,
        inches: entry.inches,
        note: entry.note,
      ),
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueWaistLogDelete(DateTime date) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.waistCircumference,
      action: SyncAction.delete,
      entityId: date.toParsedDay(),
      payload: {'loggedOn': date.toParsedDay()},
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueWeeklyMacroTargetUpsert(
    WeeklyMacroTargetEntity target,
  ) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.weeklyMacroTargets,
      action: SyncAction.create,
      entityId: target.id,
      payload: CalorieTrackerSyncMapper.weeklyMacroTargetPayload(target),
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueWeeklyMacroTargetDelete(String id) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.weeklyMacroTargets,
      action: SyncAction.delete,
      entityId: id,
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueMacroTargetUpsert(MacroTargetEntity target) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.macroTargets,
      action: SyncAction.create,
      entityId: target.id,
      payload: CalorieTrackerSyncMapper.macroTargetPayload(target),
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueMacroTargetDelete(String id) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.macroTargets,
      action: SyncAction.delete,
      entityId: id,
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueWeeklyMealUpsert(WeeklyMealEntity meal) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.weeklyMeals,
      action: SyncAction.create,
      entityId: meal.id,
      payload: CalorieTrackerSyncMapper.weeklyMealPayload(meal),
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueWeeklyMealDelete(String id) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.weeklyMeals,
      action: SyncAction.delete,
      entityId: id,
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueWeeklyMealPlanEntryUpsert(
    WeeklyMealPlanEntryEntity entry,
  ) async {
    if (!await _credentials.isConfigured()) return;
    final foodId = CalorieTrackerSyncMapper.syncFoodId(entry.foodId);
    await _outbox.enqueue(
      entityType: SyncEntityType.foods,
      action: SyncAction.create,
      entityId: foodId,
      payload: CalorieTrackerSyncMapper.foodPayloadFromPlanEntry(
        foodName: entry.foodName,
        brand: entry.brand,
        caloriesPer100: entry.caloriesPer100,
        proteinPer100: entry.proteinPer100,
        fatPer100: entry.fatPer100,
        carbsPer100: entry.carbsPer100,
      ),
    );
    await _outbox.enqueue(
      entityType: SyncEntityType.weeklyMealPlanEntries,
      action: SyncAction.create,
      entityId: entry.id,
      payload: CalorieTrackerSyncMapper.weeklyMealPlanEntryPayload(
        entry,
        foodIdOverride: foodId,
      ),
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueWeeklyMealPlanEntryDelete(String id) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.weeklyMealPlanEntries,
      action: SyncAction.delete,
      entityId: id,
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueDayMealUpsert(DayMealEntity meal) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.dayMeals,
      action: SyncAction.create,
      entityId: meal.id,
      payload: CalorieTrackerSyncMapper.dayMealEntityPayload(meal),
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueDayMealDelete(String id) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.dayMeals,
      action: SyncAction.delete,
      entityId: id,
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueMealPlanEntryUpsert(MealPlanEntryEntity entry) async {
    if (!await _credentials.isConfigured()) return;
    final foodId = CalorieTrackerSyncMapper.syncFoodId(entry.foodId);
    await _outbox.enqueue(
      entityType: SyncEntityType.foods,
      action: SyncAction.create,
      entityId: foodId,
      payload: CalorieTrackerSyncMapper.foodPayloadFromPlanEntry(
        foodName: entry.foodName,
        brand: entry.brand,
        caloriesPer100: entry.caloriesPer100,
        proteinPer100: entry.proteinPer100,
        fatPer100: entry.fatPer100,
        carbsPer100: entry.carbsPer100,
      ),
    );
    await _outbox.enqueue(
      entityType: SyncEntityType.mealPlanEntries,
      action: SyncAction.create,
      entityId: entry.id,
      payload: CalorieTrackerSyncMapper.mealPlanEntryPayload(
        entry,
        foodIdOverride: foodId,
      ),
    );
    await refreshPendingCount();
    unawaited(syncNow());
  }

  Future<void> enqueueMealPlanEntryDelete(String id) async {
    if (!await _credentials.isConfigured()) return;
    await _outbox.enqueue(
      entityType: SyncEntityType.mealPlanEntries,
      action: SyncAction.delete,
      entityId: id,
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
      var pushOk = true;
      try {
        // First sync: upload any local meal plans that predate enabling sync,
        // then pull remote plans so both directions populate.
        final firstSync = await _credentials.getLastPullAt() == null;
        if (firstSync) {
          await _seedOutboxFromLocalMealPlans();
        }
        try {
          await _pushOutbox();
        } catch (error, stackTrace) {
          // Pull must still run — REST → Hive is how the diary/plan screens
          // get populated, and a bad local outbox row must not block that.
          pushOk = false;
          _log.warning('Push failed; continuing with pull', error, stackTrace);
          _lastError = error.toString();
        }
        if (pull) {
          await _pullRemote();
        }
        _lastSyncAt = DateTime.now().toUtc();
        await refreshPendingCount();
        return pushOk;
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

  /// Queues every local daily/weekly meal plan + macro target for push.
  ///
  /// Used on the first sync so plans created before credentials were saved
  /// still reach the server. Collapsing in the outbox keeps this compact.
  Future<void> _seedOutboxFromLocalMealPlans() async {
    for (final meal in await _dayMealRepository.getAll()) {
      if (!CalorieTrackerSyncMapper.isUuid(meal.id)) continue;
      await _outbox.enqueue(
        entityType: SyncEntityType.dayMeals,
        action: SyncAction.create,
        entityId: meal.id,
        payload: CalorieTrackerSyncMapper.dayMealEntityPayload(meal),
      );
    }
    for (final entry in await _mealPlanEntryRepository.getAll()) {
      if (!CalorieTrackerSyncMapper.isUuid(entry.id) ||
          !CalorieTrackerSyncMapper.isUuid(entry.dayMealId)) {
        continue;
      }
      final foodId = CalorieTrackerSyncMapper.syncFoodId(entry.foodId);
      await _outbox.enqueue(
        entityType: SyncEntityType.foods,
        action: SyncAction.create,
        entityId: foodId,
        payload: CalorieTrackerSyncMapper.foodPayloadFromPlanEntry(
          foodName: entry.foodName,
          brand: entry.brand,
          caloriesPer100: entry.caloriesPer100,
          proteinPer100: entry.proteinPer100,
          fatPer100: entry.fatPer100,
          carbsPer100: entry.carbsPer100,
        ),
      );
      await _outbox.enqueue(
        entityType: SyncEntityType.mealPlanEntries,
        action: SyncAction.create,
        entityId: entry.id,
        payload: CalorieTrackerSyncMapper.mealPlanEntryPayload(
          entry,
          foodIdOverride: foodId,
        ),
      );
    }
    for (final meal in await _weeklyMealRepository.getAll()) {
      if (!CalorieTrackerSyncMapper.isUuid(meal.id)) continue;
      await _outbox.enqueue(
        entityType: SyncEntityType.weeklyMeals,
        action: SyncAction.create,
        entityId: meal.id,
        payload: CalorieTrackerSyncMapper.weeklyMealPayload(meal),
      );
    }
    for (final entry in await _weeklyMealPlanEntryRepository.getAll()) {
      if (!CalorieTrackerSyncMapper.isUuid(entry.id) ||
          !CalorieTrackerSyncMapper.isUuid(entry.weeklyMealId)) {
        continue;
      }
      final foodId = CalorieTrackerSyncMapper.syncFoodId(entry.foodId);
      await _outbox.enqueue(
        entityType: SyncEntityType.foods,
        action: SyncAction.create,
        entityId: foodId,
        payload: CalorieTrackerSyncMapper.foodPayloadFromPlanEntry(
          foodName: entry.foodName,
          brand: entry.brand,
          caloriesPer100: entry.caloriesPer100,
          proteinPer100: entry.proteinPer100,
          fatPer100: entry.fatPer100,
          carbsPer100: entry.carbsPer100,
        ),
      );
      await _outbox.enqueue(
        entityType: SyncEntityType.weeklyMealPlanEntries,
        action: SyncAction.create,
        entityId: entry.id,
        payload: CalorieTrackerSyncMapper.weeklyMealPlanEntryPayload(
          entry,
          foodIdOverride: foodId,
        ),
      );
    }
    for (final target in await _macroTargetRepository.getAll()) {
      if (!CalorieTrackerSyncMapper.isUuid(target.id)) continue;
      await _outbox.enqueue(
        entityType: SyncEntityType.macroTargets,
        action: SyncAction.create,
        entityId: target.id,
        payload: CalorieTrackerSyncMapper.macroTargetPayload(target),
      );
    }
    for (final target in await _weeklyMacroTargetRepository.getAll()) {
      if (!CalorieTrackerSyncMapper.isUuid(target.id)) continue;
      await _outbox.enqueue(
        entityType: SyncEntityType.weeklyMacroTargets,
        action: SyncAction.create,
        entityId: target.id,
        payload: CalorieTrackerSyncMapper.weeklyMacroTargetPayload(target),
      );
    }
  }

  Future<void> _pushOutbox() async {
    final pending = await _outbox.getAll();
    if (pending.isEmpty) return;

    final syncOps = pending
        .where((op) => op.entityType.isSyncPushEntity)
        .toList();
    final weightOps = pending
        .where((op) => op.entityType == SyncEntityType.bodyWeight)
        .toList();
    final waistOps = pending
        .where((op) => op.entityType == SyncEntityType.waistCircumference)
        .toList();

    if (syncOps.isNotEmpty) {
      // Remap / drop ops the API would reject (non-UUID entityIds such as
      // Fitty Agent's `agent:oatmeal` food codes). Dropped ops are removed
      // from the outbox so they cannot block every subsequent sync.
      final sanitized = <SyncOperation>[];
      final dropIds = <String>[];
      for (final op in syncOps) {
        final fixed = CalorieTrackerSyncMapper.sanitizePushOperation(op);
        if (fixed == null) {
          _log.warning(
            'Dropping sync push op ${op.entityType.apiName}/${op.entityId}: '
            'not a valid UUID and could not be remapped',
          );
          dropIds.add(op.id);
          continue;
        }
        sanitized.add(fixed);
      }
      if (dropIds.isNotEmpty) {
        await _outbox.removeAll(dropIds);
      }
      if (sanitized.isNotEmpty) {
        await _api.pushMutations(sanitized);
        await _outbox.removeAll(sanitized.map((op) => op.id));
      }
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

    for (final op in waistOps) {
      try {
        if (op.action == SyncAction.delete) {
          await _outbox.remove(op.id);
          continue;
        }
        await _api.upsertWaistCircumference(op.payload ?? const {});
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
    final foodById = {
      for (final f in _maps(pull, 'foods')) f['id'] as String: f,
    };

    final pending = await _outbox.getAll();
    Set<String> pendingOf(SyncEntityType type) => pending
        .where((op) => op.entityType == type)
        .map((op) => op.entityId)
        .toSet();

    await _applyFoodLogEntries(
      _maps(pull, 'foodLogEntries'),
      foodById,
      pendingOf(SyncEntityType.foodLogEntries),
    );
    await _applyDayMeals(
      _maps(pull, 'dayMeals'),
      pendingOf(SyncEntityType.dayMeals),
    );
    await _applyMealPlanEntries(
      _maps(pull, 'mealPlanEntries'),
      foodById,
      pendingOf(SyncEntityType.mealPlanEntries),
    );
    await _applyWeeklyMeals(
      _maps(pull, 'weeklyMeals'),
      pendingOf(SyncEntityType.weeklyMeals),
    );
    await _applyWeeklyMealPlanEntries(
      _maps(pull, 'weeklyMealPlanEntries'),
      foodById,
      pendingOf(SyncEntityType.weeklyMealPlanEntries),
    );
    await _applyMacroTargets(
      _maps(pull, 'macroTargets'),
      pendingOf(SyncEntityType.macroTargets),
    );
    await _applyWeeklyMacroTargets(
      _maps(pull, 'weeklyMacroTargets'),
      pendingOf(SyncEntityType.weeklyMacroTargets),
    );

    final serverTime = pull['serverTime'] as String?;
    await _credentials.setLastPullAt(
      serverTime != null ? DateTime.parse(serverTime) : DateTime.now().toUtc(),
    );
  }

  List<Map<String, dynamic>> _maps(Map<String, dynamic> pull, String key) {
    return (pull[key] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _applyFoodLogEntries(
    List<Map<String, dynamic>> logs,
    Map<String, Map<String, dynamic>> foodById,
    Set<String> pendingIds,
  ) async {
    final toApply = <IntakeDBO>[];
    for (final log in logs) {
      final id = log['id'] as String?;
      if (id == null || pendingIds.contains(id)) continue;
      if (log['deletedAt'] != null) {
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
  }

  Future<void> _applyDayMeals(
    List<Map<String, dynamic>> rows,
    Set<String> pendingIds,
  ) async {
    final toUpsert = <DayMealEntity>[];
    for (final raw in rows) {
      final id = raw['id'] as String?;
      if (id == null || pendingIds.contains(id)) continue;
      if (raw['deletedAt'] != null) {
        await _dayMealRepository.deleteById(id);
        continue;
      }
      final entity = CalorieTrackerSyncMapper.dayMealFromRemote(raw);
      if (entity != null) toUpsert.add(entity);
    }
    if (toUpsert.isNotEmpty) {
      await _dayMealRepository.upsertAll(toUpsert);
    }
  }

  Future<void> _applyMealPlanEntries(
    List<Map<String, dynamic>> rows,
    Map<String, Map<String, dynamic>> foodById,
    Set<String> pendingIds,
  ) async {
    final toUpsert = <MealPlanEntryEntity>[];
    for (final raw in rows) {
      final id = raw['id'] as String?;
      if (id == null || pendingIds.contains(id)) continue;
      if (raw['deletedAt'] != null) {
        await _mealPlanEntryRepository.deleteById(id);
        continue;
      }
      final foodId = raw['foodId'] as String?;
      final entity = CalorieTrackerSyncMapper.mealPlanEntryFromRemote(
        raw,
        foodId == null ? null : foodById[foodId],
      );
      if (entity != null) toUpsert.add(entity);
    }
    if (toUpsert.isNotEmpty) {
      await _mealPlanEntryRepository.upsertAll(toUpsert);
    }
  }

  Future<void> _applyWeeklyMeals(
    List<Map<String, dynamic>> rows,
    Set<String> pendingIds,
  ) async {
    final toUpsert = <WeeklyMealEntity>[];
    for (final raw in rows) {
      final id = raw['id'] as String?;
      if (id == null || pendingIds.contains(id)) continue;
      if (raw['deletedAt'] != null) {
        await _weeklyMealRepository.deleteById(id);
        continue;
      }
      final entity = CalorieTrackerSyncMapper.weeklyMealFromRemote(raw);
      if (entity != null) toUpsert.add(entity);
    }
    if (toUpsert.isNotEmpty) {
      await _weeklyMealRepository.upsertAll(toUpsert);
    }
  }

  Future<void> _applyWeeklyMealPlanEntries(
    List<Map<String, dynamic>> rows,
    Map<String, Map<String, dynamic>> foodById,
    Set<String> pendingIds,
  ) async {
    final toUpsert = <WeeklyMealPlanEntryEntity>[];
    for (final raw in rows) {
      final id = raw['id'] as String?;
      if (id == null || pendingIds.contains(id)) continue;
      if (raw['deletedAt'] != null) {
        await _weeklyMealPlanEntryRepository.deleteById(id);
        continue;
      }
      final foodId = raw['foodId'] as String?;
      final entity = CalorieTrackerSyncMapper.weeklyMealPlanEntryFromRemote(
        raw,
        foodId == null ? null : foodById[foodId],
      );
      if (entity != null) toUpsert.add(entity);
    }
    if (toUpsert.isNotEmpty) {
      await _weeklyMealPlanEntryRepository.upsertAll(toUpsert);
    }
  }

  Future<void> _applyMacroTargets(
    List<Map<String, dynamic>> rows,
    Set<String> pendingIds,
  ) async {
    for (final raw in rows) {
      final id = raw['id'] as String?;
      if (id == null || pendingIds.contains(id)) continue;
      if (raw['deletedAt'] != null) {
        await _macroTargetRepository.deleteById(id);
        continue;
      }
      final entity = CalorieTrackerSyncMapper.macroTargetFromRemote(raw);
      if (entity != null) {
        await _macroTargetRepository.upsert(entity);
      }
    }
  }

  Future<void> _applyWeeklyMacroTargets(
    List<Map<String, dynamic>> rows,
    Set<String> pendingIds,
  ) async {
    for (final raw in rows) {
      final id = raw['id'] as String?;
      if (id == null || pendingIds.contains(id)) continue;
      if (raw['deletedAt'] != null) {
        await _weeklyMacroTargetRepository.deleteById(id);
        continue;
      }
      final entity = CalorieTrackerSyncMapper.weeklyMacroTargetFromRemote(raw);
      if (entity != null) {
        await _weeklyMacroTargetRepository.upsert(entity);
      }
    }
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
