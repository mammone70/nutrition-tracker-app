import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/sync/calorie_tracker_sync_credentials.dart';
import 'package:opennutritracker/core/sync/sync_operation.dart';

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

/// HTTP client for mammone70/calorie-tracker (`/api` prefix).
class CalorieTrackerApiClient {
  final http.Client _http;
  final CalorieTrackerSyncCredentials _credentials;
  final _log = Logger('CalorieTrackerApiClient');

  CalorieTrackerApiClient(this._http, this._credentials);

  Future<Uri> _uri(String path, [Map<String, String>? query]) async {
    final base = await _credentials.getBaseUrl();
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized').replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final tz = await _credentials.getTimezone();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-User-Timezone': tz,
    };
    if (withAuth) {
      final token = await _credentials.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<CalorieTrackerApiProbeResult> probe() async {
    try {
      final uri = await _uri('/health');
      final response = await _http
          .get(uri, headers: await _headers(withAuth: false))
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
      return CalorieTrackerApiProbeResult(ok: false, message: error.toString());
    }
  }

  /// Email/password login; stores access + refresh tokens on success.
  Future<void> login() async {
    final email = await _credentials.getEmail();
    final password = await _credentials.getPassword();
    if (email == null || password == null) {
      throw StateError('Email and password are required to sign in.');
    }
    final uri = await _uri('/auth/login');
    final response = await _http
        .post(
          uri,
          headers: await _headers(withAuth: false),
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 30));
    _throwIfFailed(response, 'POST /auth/login');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    await _credentials.setTokens(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
    );
  }

  Future<bool> refreshSession() async {
    final refresh = await _credentials.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    final uri = await _uri('/auth/refresh');
    final response = await _http
        .post(
          uri,
          headers: await _headers(withAuth: false),
          body: jsonEncode({'refreshToken': refresh}),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    await _credentials.setTokens(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
    );
    return true;
  }

  /// Ensures a valid access token (login or refresh as needed).
  Future<void> ensureAuthenticated() async {
    final access = await _credentials.getAccessToken();
    if (access != null && access.isNotEmpty) return;
    if (await refreshSession()) return;
    await login();
  }

  Future<http.Response> _authorized(
    Future<http.Response> Function() send,
  ) async {
    await ensureAuthenticated();
    var response = await send();
    if (response.statusCode == 401) {
      final refreshed = await refreshSession();
      if (!refreshed) {
        await login();
      }
      response = await send();
    }
    return response;
  }

  Future<Map<String, dynamic>> pullSince(DateTime? since) async {
    final query = <String, String>{
      if (since != null) 'since': since.toUtc().toIso8601String(),
    };
    final response = await _authorized(() async {
      final uri = await _uri('/sync', query);
      return _http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 60));
    });
    _throwIfFailed(response, 'GET /sync');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> pushMutations(List<SyncOperation> operations) async {
    if (operations.isEmpty) return;
    final body = {
      'mutations': operations.map((op) => op.toPushMutation()).toList(),
    };
    final response = await _authorized(() async {
      final uri = await _uri('/sync/push');
      return _http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    });
    _throwIfFailed(response, 'POST /sync/push');
  }

  Future<void> upsertBodyWeight(Map<String, dynamic> payload) async {
    final response = await _authorized(() async {
      final uri = await _uri('/body-weight');
      return _http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
    });
    _throwIfFailed(response, 'POST /body-weight');
  }

  Future<void> deleteBodyWeight(String id) async {
    final response = await _authorized(() async {
      final uri = await _uri('/body-weight/${Uri.encodeComponent(id)}');
      return _http
          .delete(uri, headers: await _headers())
          .timeout(const Duration(seconds: 30));
    });
    if (response.statusCode == 404) return;
    _throwIfFailed(response, 'DELETE /body-weight');
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
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
