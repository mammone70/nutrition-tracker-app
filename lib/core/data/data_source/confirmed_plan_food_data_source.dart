import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/confirmed_plan_food_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class ConfirmedPlanFoodDataSource {
  final log = Logger('ConfirmedPlanFoodDataSource');
  final HiveDBProvider _db;

  ConfirmedPlanFoodDataSource(this._db);

  Box<ConfirmedPlanFoodDBO> get _box => _db.confirmedPlanFoodBox;

  Future<void> putLink({
    required String planDate,
    required String entryId,
    required String intakeId,
  }) async {
    final dbo = ConfirmedPlanFoodDBO(
      planDate: planDate,
      entryId: entryId,
      intakeId: intakeId,
    );
    await _box.put(dbo.boxKey, dbo);
  }

  ConfirmedPlanFoodDBO? getLink({
    required String planDate,
    required String entryId,
  }) {
    return _box.get(
      ConfirmedPlanFoodDBO.keyFor(planDate: planDate, entryId: entryId),
    );
  }

  Map<String, String> intakeIdsForDate(String planDate) {
    final out = <String, String>{};
    for (final dbo in _box.values) {
      if (dbo.planDate == planDate) {
        out[dbo.entryId] = dbo.intakeId;
      }
    }
    return out;
  }

  Future<void> removeLink({
    required String planDate,
    required String entryId,
  }) async {
    await _box.delete(
      ConfirmedPlanFoodDBO.keyFor(planDate: planDate, entryId: entryId),
    );
  }

  Future<void> removeByIntakeId(String intakeId) async {
    final toDelete = _box.values
        .where((dbo) => dbo.intakeId == intakeId)
        .map((dbo) => dbo.boxKey)
        .toList();
    for (final key in toDelete) {
      await _box.delete(key);
    }
  }
}
