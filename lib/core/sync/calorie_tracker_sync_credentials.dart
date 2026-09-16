import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';

/// Opt-in credentials for the mammone70/calorie-tracker REST API.
///
/// Kept in secure storage (not Hive) so a wiped diary box cannot leave a
/// bearer token behind, and so the sync layer can decide whether it is
/// enabled before any profile boxes open.
class CalorieTrackerSyncCredentials {
  static const _enabledKey = 'CalorieTrackerSyncEnabled';
  static const _baseUrlKey = 'CalorieTrackerSyncBaseUrl';
  static const _tokenKey = 'CalorieTrackerSyncBearerToken';
  static const _lastPullKey = 'CalorieTrackerSyncLastPullAt';

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

  /// Base URL without a trailing slash, e.g. `https://api.example.com`.
  Future<String?> getBaseUrl() => _storage.read(key: _baseUrlKey);

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

  Future<String?> getBearerToken() => _storage.read(key: _tokenKey);

  Future<void> setBearerToken(String? token) async {
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _storage.delete(key: _tokenKey);
      return;
    }
    await _storage.write(key: _tokenKey, value: trimmed);
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

  /// True when sync is opted in and both URL and token are present.
  Future<bool> isConfigured() async {
    if (!await isEnabled()) return false;
    final url = await getBaseUrl();
    final token = await getBearerToken();
    return url != null &&
        url.isNotEmpty &&
        token != null &&
        token.isNotEmpty;
  }

  Future<void> clear() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _baseUrlKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _lastPullKey);
  }
}
