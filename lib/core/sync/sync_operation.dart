/// Resource kinds mirrored to the calorie-tracker REST API.
///
/// Values are stable storage tags for the sync outbox — renaming one orphans
/// queued operations.
enum SyncResource {
  intake,
  activity,
  trackedDay,
  weightLog,
  waterIntake,
  user,
}

/// Whether a queued mutation creates/updates or deletes a remote record.
enum SyncMutation {
  upsert,
  delete,
}

/// One pending local → remote change.
///
/// The diary stays in Hive; this record is only a reminder to push when the
/// network is back. [payload] is the JSON body for upserts (export-format
/// DBO shape). Deletes keep [resourceId] so the remote row can be removed
/// after the local row is already gone.
class SyncOperation {
  final String id;
  final SyncResource resource;
  final SyncMutation mutation;
  final String resourceId;
  final Map<String, dynamic>? payload;
  final DateTime enqueuedAt;
  final int attempts;
  final String? lastError;

  const SyncOperation({
    required this.id,
    required this.resource,
    required this.mutation,
    required this.resourceId,
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
      resource: resource,
      mutation: mutation,
      resourceId: resourceId,
      enqueuedAt: enqueuedAt,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
      lastError: lastError,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'resource': resource.name,
        'mutation': mutation.name,
        'resourceId': resourceId,
        'payload': payload,
        'enqueuedAt': enqueuedAt.toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      resource: SyncResource.values.byName(json['resource'] as String),
      mutation: SyncMutation.values.byName(json['mutation'] as String),
      resourceId: json['resourceId'] as String,
      payload: json['payload'] == null
          ? null
          : Map<String, dynamic>.from(json['payload'] as Map),
      enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
      attempts: json['attempts'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}
