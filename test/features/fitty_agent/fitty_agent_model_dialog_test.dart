import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/features/fitty_agent/domain/fitty_agent_consent_storage.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_model_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Fitty Chat model dialog lists cheaper OpenRouter options', (
    tester,
  ) async {
    final backing = _MemoryStorage();
    final credentials = AiCredentialStorage(backing);
    final agentSettings = FittyAgentConsentStorage(storage: backing);

    await credentials.setTermsAccepted(true);
    await credentials.writeApiKey('sk-or', provider: AiProvider.openrouter);
    await credentials.setActiveProvider(AiProvider.openrouter);
    await credentials.setEnabled(true);
    // Meal-assist default stays sonnet; agent should highlight luna for chat.
    await credentials.writeModel(
      'anthropic/claude-sonnet-5',
      provider: AiProvider.openrouter,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => FittyAgentModelDialog(
                      agentSettings: agentSettings,
                      credentials: credentials,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Fitty Chat model'), findsOneWidget);
    expect(
      find.textContaining(
        'Fitty Chat can use a cheaper model than meal photo analysis',
      ),
      findsOneWidget,
    );
    expect(find.text('openai/gpt-5.6-luna'), findsOneWidget);
    expect(find.textContaining('Recommended for chat'), findsOneWidget);
    expect(find.text('anthropic/claude-sonnet-5'), findsOneWidget);
    expect(find.text('anthropic/claude-haiku-4.5'), findsOneWidget);

    // Selecting haiku stores an agent-only preference.
    await tester.tap(find.text('anthropic/claude-haiku-4.5'));
    await tester.pumpAndSettle();
    expect(
      await agentSettings.readModel(provider: AiProvider.openrouter),
      'anthropic/claude-haiku-4.5',
    );
    expect(
      (await credentials.readSelection())!.modelId,
      'anthropic/claude-sonnet-5',
    );
  });
}
