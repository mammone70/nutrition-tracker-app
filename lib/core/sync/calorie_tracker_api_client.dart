import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_sync_credentials.dart';
import 'package:opennutritracker/core/sync/sync_operation.dart';

/// Result of probing the configured calorie-tracker API.
class CalorieTrackerApiProbeResult {
  final bool ok;
  final int? statusCode;
  final String message;

  const CalorieTrackerApiProbeResult({
    required this.ok,
    required this.message,
    this.statusCode,
  });
}

/// HTTP client for the mammone70/calorie-tracker REST API.
///
/// Endpoint paths follow the provisional contract in
/// `docs/calorie-tracker-sync.md`. When the live API differs, adapt the
/// path helpers and payload mapping here — the outbox and local-first
/// write path stay unchanged.
class CalorieTrackerApiClient {
  final http.Client _http;
  final CalorieTrackerSyncCredentials _credentials;
  final _log = Logger('CalorieTrackerApiClient');

  CalorieTrackerApiClient(this._http, this._credentials);

  Future<Map<String, String>> _headers() async {
    final token = await _credentials.getBearerToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Uri> _uri(String path, [Map<String, String>? query]) async {
    final base = await _credentials.getBaseUrl();
    if (base == null || base.isEmpty) {
      throw StateError('Calorie-tracker sync base URL is not configured.');
    }
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  String _collectionPath(SyncResource resource) {
    switch (resource) {
      case SyncResource.intake:
        return '/v1/intakes';
      case SyncResource.activity:
        return '/v1/activities';
      case SyncResource.trackedDay:
        return '/v1/tracked-days';
      case SyncResource.weightLog:
        return '/v1/weight-log';
      case SyncResource.waterIntake:
        return '/v1/water-intake';
      case SyncResource.user:
        return '/v1/user';
    }
  }

  String _itemPath(SyncResource resource, String resourceId) {
    if (resource == SyncResource.user) {
      return '/v1/user';
    }
    return '${_collectionPath(resource)}/${Uri.encodeComponent(resourceId)}';
  }

  Future<CalorieTrackerApiProbeResult> probe() async {
    try {
      final uri = await _uri('/health');
      final response = await _http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return CalorieTrackerApiProbeResult(
          ok: true,
          statusCode: response.statusCode,
          message: 'Reachable',
        );
      }
      return CalorieTrackerApiProbeResult(
        ok: false,
        statusCode: response.statusCode,
        message: 'HTTP ${response.statusCode}',
      );
    } catch (error, stackTrace) {
      _log.warning('Probe failed', error, stackTrace);
      return CalorieTrackerApiProbeResult(
        ok: false,
        message: error.toString(),
      );
    }
  }

  /// Applies one outbox mutation to the remote API.
  Future<void> apply(SyncOperation operation) async {
    final headers = await _headers();
    if (operation.mutation == SyncMutation.delete) {
      final uri = await _uri(_itemPath(operation.resource, operation.resourceId));
      final response = await _http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
      _throwIfFailed(response, 'DELETE ${operation.resource.name}');
      return;
    }

    final payload = operation.payload;
    if (payload == null) {
      throw StateError(
        'Upsert for ${operation.resource.name}/${operation.resourceId} '
        'has no payload.',
      );
    }

    if (operation.resource == SyncResource.user) {
      final uri = await _uri('/v1/user');
      final response = await _http
          .put(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));
      _throwIfFailed(response, 'PUT user');
      return;
    }

    final uri =
        await _uri(_itemPath(operation.resource, operation.resourceId));
    final response = await _http
        .put(uri, headers: headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 30));
    _throwIfFailed(response, 'PUT ${operation.resource.name}');
  }

  /// Pulls remote records changed at or after [since] (inclusive).
  ///
  /// Returns a map of resource → list of JSON objects in export/DBO shape.
  Future<Map<SyncResource, List<Map<String, dynamic>>>> pullSince(
    DateTime? since,
  ) async {
    final query = <String, String>{
      if (since != null) 'since': since.toUtc().toIso8601String(),
    };
    final headers = await _headers();
    final result = <SyncResource, List<Map<String, dynamic>>>{};

    for (final resource in SyncResource.values) {
      if (resource == SyncResource.user) {
        final uri = await _uri('/v1/user');
        final response = await _http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 404) {
          result[resource] = const [];
          continue;
        }
        _throwIfFailed(response, 'GET user');
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          result[resource] = [decoded];
        } else {
          result[resource] = const [];
        }
        continue;
      }

      final uri = await _uri(_collectionPath(resource), query);
      final response = await _http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
      _throwIfFailed(response, 'GET ${resource.name}');
      result[resource] = _decodeList(response.body);
    }
    return result;
  }

  List<Map<String, dynamic>> _decodeList(String body) {
    if (body.isEmpty) return const [];
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is Map && decoded['items'] is List) {
      return (decoded['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      return [decoded];
    }
    return const [];
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    // Treat 404 on delete as success — remote already gone.
    if (response.statusCode == 404 && action.startsWith('DELETE')) return;
    throw CalorieTrackerApiException(
      action: action,
      statusCode: response.statusCode,
      body: response.body,
    );
  }
}

class CalorieTrackerApiException implements Exception {
  final String action;
  final int statusCode;
  final String body;

  CalorieTrackerApiException({
    required this.action,
    required this.statusCode,
    required this.body,
  });

  @override
  String toString() =>
      'CalorieTrackerApiException($action → HTTP $statusCode): $body';
}
