import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';

/// Separate agreement from AI meal assist: Fitty Agent may send diary,
/// profile, and plan summaries to the configured LLM.
class FittyAgentConsentStorage {
  static const _key = 'FittyAgentConsentGiven';

  final FlutterSecureStorage _storage;

  FittyAgentConsentStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? SecureAppStorageProvider.secureAppStorage;

  Future<bool> hasConsent() async {
    final value = await _storage.read(key: _key);
    return value == 'true';
  }

  Future<void> setConsent(bool given) async {
    if (given) {
      await _storage.write(key: _key, value: 'true');
    } else {
      await _storage.delete(key: _key);
    }
  }
}
