import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';

/// Opt-in credentials for the mammone70/calorie-tracker REST API.
///
/// Auth is JWT (access + refresh). Tokens and the optional password live in
/// secure storage so a wiped Hive diary cannot leave session material behind.
class CalorieTrackerSyncCredentials {
  static const _enabledKey = 'CalorieTrackerSyncEnabled';
  static const _baseUrlKey = 'CalorieTrackerSyncBaseUrl';
  static const _emailKey = 'CalorieTrackerSyncEmail';
  static const _passwordKey = 'CalorieTrackerSyncPassword';
  static const _accessTokenKey = 'CalorieTrackerSyncAccessToken';
  static const _refreshTokenKey = 'CalorieTrackerSyncRefreshToken';
  static const _lastPullKey = 'CalorieTrackerSyncLastPullAt';
  static const _timezoneKey = 'CalorieTrackerSyncTimezone';

  /// Production API from calorie-tracker README.
  static const defaultBaseUrl = 'https://api.cal-count.mammonesoftware.org/api';

  final FlutterSecureStorage _storage;

  CalorieTrackerSyncCredentials({FlutterSecureStorage? storage})
      : _storage = storage ?? SecureAppStorageProvider.secureAppStorage;

  Future<bool> isEnabled() async {
    final raw = await _storage.read(key: _enabledKey);
    return raw == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _enabledKey, value: enabled ? 'true' : 'false');
  }

  /// Base URL including `/api`, no trailing slash.
  Future<String> getBaseUrl() async {
    final raw = await _storage.read(key: _baseUrlKey);
    if (raw == null || raw.trim().isEmpty) return defaultBaseUrl;
    final trimmed = raw.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  Future<void> setBaseUrl(String? url) async {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _storage.delete(key: _baseUrlKey);
      return;
    }
    await _storage.write(
      key: _baseUrlKey,
      value: trimmed.endsWith('/')
          ? trimmed.substring(0, trimmed.length - 1)
          : trimmed,
    );
  }

  Future<String?> getEmail() => _storage.read(key: _emailKey);

  Future<void> setEmail(String? email) async {
    final trimmed = email?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _storage.delete(key: _emailKey);
      return;
    }
    await _storage.write(key: _emailKey, value: trimmed);
  }

  Future<String?> getPassword() => _storage.read(key: _passwordKey);

  Future<void> setPassword(String? password) async {
    if (password == null || password.isEmpty) {
      await _storage.delete(key: _passwordKey);
      return;
    }
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<void> setAccessToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _storage.delete(key: _accessTokenKey);
      return;
    }
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> setRefreshToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _storage.delete(key: _refreshTokenKey);
      return;
    }
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await setAccessToken(accessToken);
    await setRefreshToken(refreshToken);
  }

  Future<DateTime?> getLastPullAt() async {
    final raw = await _storage.read(key: _lastPullKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastPullAt(DateTime? at) async {
    if (at == null) {
      await _storage.delete(key: _lastPullKey);
      return;
    }
    await _storage.write(key: _lastPullKey, value: at.toUtc().toIso8601String());
  }

  Future<String> getTimezone() async {
    final raw = await _storage.read(key: _timezoneKey);
    if (raw == null || raw.isEmpty) return 'America/Los_Angeles';
    return raw;
  }

  Future<void> setTimezone(String? tz) async {
    final trimmed = tz?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _storage.delete(key: _timezoneKey);
      return;
    }
    await _storage.write(key: _timezoneKey, value: trimmed);
  }

  /// Sync runs when opted in and a JWT (or login credentials) is available.
  Future<bool> isConfigured() async {
    if (!await isEnabled()) return false;
    final access = await getAccessToken();
    if (access != null && access.isNotEmpty) return true;
    final email = await getEmail();
    final password = await getPassword();
    return email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _baseUrlKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _lastPullKey);
    await _storage.delete(key: _timezoneKey);
  }
}
