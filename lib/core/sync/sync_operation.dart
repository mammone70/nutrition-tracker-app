/// Entity types accepted by `POST /api/sync/push` on calorie-tracker.
enum SyncEntityType {
  foods('foods'),
  dayMeals('day_meals'),
  foodLogEntries('food_log_entries'),
  macroTargets('macro_targets'),
  weeklyMacroTargets('weekly_macro_targets'),
  weeklyMeals('weekly_meals'),
  weeklyMealPlanEntries('weekly_meal_plan_entries'),
  mealPlanEntries('meal_plan_entries'),
  exercises('exercises'),
  /// Local-only: pushed via `POST /api/body-weight`, not `/api/sync/push`.
  bodyWeight('__body_weight');

  final String apiName;
  const SyncEntityType(this.apiName);

  bool get isSyncPushEntity => this != SyncEntityType.bodyWeight;

  static SyncEntityType fromApiName(String name) {
    return SyncEntityType.values.firstWhere((e) => e.apiName == name);
  }
}

enum SyncAction {
  create,
  update,
  delete,
}

/// One pending local → remote mutation matching calorie-tracker sync push.
class SyncOperation {
  final String id;
  final SyncEntityType entityType;
  final SyncAction action;
  final String entityId;
  final Map<String, dynamic>? payload;
  final DateTime clientUpdatedAt;
  final DateTime enqueuedAt;
  final int attempts;
  final String? lastError;

  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.action,
    required this.entityId,
    required this.clientUpdatedAt,
    required this.enqueuedAt,
    this.payload,
    this.attempts = 0,
    this.lastError,
  });

  SyncOperation copyWith({
    int? attempts,
    String? lastError,
    Map<String, dynamic>? payload,
  }) {
    return SyncOperation(
      id: id,
      entityType: entityType,
      action: action,
      entityId: entityId,
      clientUpdatedAt: clientUpdatedAt,
      enqueuedAt: enqueuedAt,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
      lastError: lastError,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType.apiName,
        'action': action.name,
        'entityId': entityId,
        'payload': payload,
        'clientUpdatedAt': clientUpdatedAt.toUtc().toIso8601String(),
        'enqueuedAt': enqueuedAt.toUtc().toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
      };

  /// Wire format for `POST /api/sync/push`.
  Map<String, dynamic> toPushMutation() => {
        'entityType': entityType.apiName,
        'entityId': entityId,
        'action': action.name,
        if (payload != null) 'payload': payload,
        'clientUpdatedAt': clientUpdatedAt.toUtc().toIso8601String(),
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      entityType: SyncEntityType.fromApiName(json['entityType'] as String),
      action: SyncAction.values.byName(json['action'] as String),
      entityId: json['entityId'] as String,
      payload: json['payload'] == null
          ? null
          : Map<String, dynamic>.from(json['payload'] as Map),
      clientUpdatedAt: DateTime.parse(json['clientUpdatedAt'] as String),
      enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
      attempts: json['attempts'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}
