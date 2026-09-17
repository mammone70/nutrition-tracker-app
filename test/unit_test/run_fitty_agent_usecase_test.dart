import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/core/utils/ai_model_catalogue.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_llm_api.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_tool.dart';
import 'package:opennutritracker/features/fitty_agent/domain/fitty_agent_consent_storage.dart';
import 'package:opennutritracker/features/fitty_agent/domain/run_fitty_agent_usecase.dart';

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

class _RecordingApi implements AgentLlmApi {
  _RecordingApi(this.selection);

  final AiSelection selection;

  @override
  Future<AgentTurnResult> runTurn({
    required String system,
    required List<AgentMessage> history,
    required List<AgentToolDefinition> tools,
    required Future<String> Function(AgentToolCall call) executeTool,
    int maxRounds = 24,
  }) async {
    return const AgentTurnResult(reply: 'ok', newMessages: []);
  }
}

void main() {
  late _MemoryStorage backing;
  late AiCredentialStorage credentials;
  late FittyAgentConsentStorage agentSettings;
  late RunFittyAgentUseCase useCase;
  AiSelection? seenSelection;

  setUp(() async {
    backing = _MemoryStorage();
    credentials = AiCredentialStorage(backing);
    agentSettings = FittyAgentConsentStorage(storage: backing);
    await credentials.setTermsAccepted(true);
    await credentials.writeApiKey('sk-test', provider: AiProvider.openrouter);
    await credentials.setActiveProvider(AiProvider.openrouter);
    await credentials.setEnabled(true);
    await agentSettings.setConsent(true);

    useCase = RunFittyAgentUseCase(
      credentials: credentials,
      consent: agentSettings,
      httpClient: http.Client(),
      executeTool: (_) async => '{}',
      apiFactory: (client, selection) {
        seenSelection = selection;
        return _RecordingApi(selection);
      },
    );
  });

  test('unset agent model defaults to the cheaper chat pick, not meal assist',
      () async {
    // Meal assist still resolves OpenRouter to sonnet; chat prefers luna.
    expect(
      AiModelCatalogue.resolve(AiProvider.openrouter, null)!.id,
      'anthropic/claude-sonnet-5',
    );
    expect(
      AiModelCatalogue.defaultForAgent(AiProvider.openrouter)!.id,
      'openai/gpt-5.6-luna',
    );

    final selection = await useCase.selectionForAgent();
    expect(selection!.modelId, 'openai/gpt-5.6-luna');
    expect(selection.provider, AiProvider.openrouter);
  });

  test('stored agent model is used without rewriting meal-assist model',
      () async {
    await credentials.writeModel(
      'anthropic/claude-sonnet-5',
      provider: AiProvider.openrouter,
    );
    await agentSettings.writeModel(
      'anthropic/claude-haiku-4.5',
      provider: AiProvider.openrouter,
    );

    final selection = await useCase.selectionForAgent();
    expect(selection!.modelId, 'anthropic/claude-haiku-4.5');

    final assist = await credentials.readSelection();
    expect(assist!.modelId, 'anthropic/claude-sonnet-5');
  });

  test('send overlays the agent model onto the live request', () async {
    await agentSettings.writeModel(
      'openai/gpt-5.6-terra',
      provider: AiProvider.openrouter,
    );

    await useCase.send(userText: 'hi', history: const []);
    expect(seenSelection!.modelId, 'openai/gpt-5.6-terra');
  });
}
