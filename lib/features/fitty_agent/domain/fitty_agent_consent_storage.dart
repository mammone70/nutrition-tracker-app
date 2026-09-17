import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';

/// Fitty Agent preferences that are separate from AI meal assistance.
///
/// Consent is agent-only because chat may send diary/profile summaries.
/// The model id is also agent-only so a cheaper chat model can be chosen
/// without changing the meal/photo assist model (and without clearing
/// meal-assist probe state via [AiCredentialStorage.writeModel]).
class FittyAgentConsentStorage {
  static const _consentKey = 'FittyAgentConsentGiven';
  static const _modelTag = 'FittyAgentModelTag';

  final FlutterSecureStorage _storage;

  FittyAgentConsentStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? SecureAppStorageProvider.secureAppStorage;

  static String _modelSlotTag(AiProvider provider) =>
      '$_modelTag.${provider.name}';

  Future<bool> hasConsent() async {
    final value = await _storage.read(key: _consentKey);
    return value == 'true';
  }

  Future<void> setConsent(bool given) async {
    if (given) {
      await _storage.write(key: _consentKey, value: 'true');
    } else {
      await _storage.delete(key: _consentKey);
    }
  }

  /// Stored Fitty Agent model for [provider], or null to use the agent default.
  Future<String?> readModel({required AiProvider provider}) async {
    final value = await _storage.read(key: _modelSlotTag(provider));
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> writeModel(String modelId, {required AiProvider provider}) async {
    final trimmed = modelId.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _modelSlotTag(provider));
      return;
    }
    await _storage.write(key: _modelSlotTag(provider), value: trimmed);
  }

  Future<void> clearModel({required AiProvider provider}) async {
    await _storage.delete(key: _modelSlotTag(provider));
  }

  /// Clears consent and every per-provider agent model slot.
  Future<void> clearAll() async {
    await setConsent(false);
    for (final provider in AiProvider.values) {
      await clearModel(provider: provider);
    }
  }
}
