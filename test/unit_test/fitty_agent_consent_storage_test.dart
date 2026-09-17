import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/features/fitty_agent/domain/fitty_agent_consent_storage.dart';

class _MemoryStorage implements FlutterSecureStorage {
  final store = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => store.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _MemoryStorage backing;
  late FittyAgentConsentStorage storage;

  setUp(() {
    backing = _MemoryStorage();
    storage = FittyAgentConsentStorage(storage: backing);
  });

  test('consent and model slots are independent per provider', () async {
    expect(await storage.hasConsent(), isFalse);
    await storage.setConsent(true);
    expect(await storage.hasConsent(), isTrue);

    await storage.writeModel(
      'openai/gpt-5.6-luna',
      provider: AiProvider.openrouter,
    );
    await storage.writeModel('gpt-5.6-terra', provider: AiProvider.openai);

    expect(
      await storage.readModel(provider: AiProvider.openrouter),
      'openai/gpt-5.6-luna',
    );
    expect(
      await storage.readModel(provider: AiProvider.openai),
      'gpt-5.6-terra',
    );
    expect(await storage.readModel(provider: AiProvider.anthropic), isNull);
  });

  test('clearAll removes consent and every agent model slot', () async {
    await storage.setConsent(true);
    await storage.writeModel(
      'anthropic/claude-haiku-4.5',
      provider: AiProvider.openrouter,
    );
    await storage.writeModel('gpt-5.6-luna', provider: AiProvider.openai);

    await storage.clearAll();

    expect(await storage.hasConsent(), isFalse);
    expect(await storage.readModel(provider: AiProvider.openrouter), isNull);
    expect(await storage.readModel(provider: AiProvider.openai), isNull);
    expect(backing.store, isEmpty);
  });

  test('empty write clears the slot without touching consent', () async {
    await storage.setConsent(true);
    await storage.writeModel('gpt-5.6-luna', provider: AiProvider.openai);
    await storage.writeModel('', provider: AiProvider.openai);

    expect(await storage.hasConsent(), isTrue);
    expect(await storage.readModel(provider: AiProvider.openai), isNull);
  });
}
