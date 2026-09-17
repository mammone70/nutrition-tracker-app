import 'package:http/http.dart' as http;
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/core/utils/ai_model_catalogue.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/features/fitty_agent/data/agent_llm_api_factory.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_llm_api.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_tool.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_tool_executor.dart';
import 'package:opennutritracker/features/fitty_agent/domain/fitty_agent_consent_storage.dart';
import 'package:opennutritracker/features/add_meal/domain/meal_interpreter_exception.dart';

class FittyAgentNotConfiguredException implements Exception {
  const FittyAgentNotConfiguredException();
}

class FittyAgentConsentRequiredException implements Exception {
  const FittyAgentConsentRequiredException();
}

/// One user message → model reply, with tool execution against local data.
class RunFittyAgentUseCase {
  final AiCredentialStorage _credentials;
  final FittyAgentConsentStorage _agentSettings;
  final http.Client _http;
  final AgentToolExecutor? _executor;
  final Future<String> Function(AgentToolCall call)? _executeTool;
  final AgentLlmApi Function(http.Client client, AiSelection selection)?
  _apiFactory;

  RunFittyAgentUseCase({
    required AiCredentialStorage credentials,
    required FittyAgentConsentStorage consent,
    required http.Client httpClient,
    AgentToolExecutor? executor,
    Future<String> Function(AgentToolCall call)? executeTool,
    AgentLlmApi Function(http.Client client, AiSelection selection)? apiFactory,
  }) : assert(
         executor != null || executeTool != null,
         'Provide executor or executeTool',
       ),
       _credentials = credentials,
       _agentSettings = consent,
       _http = httpClient,
       _executor = executor,
       _executeTool = executeTool,
       _apiFactory = apiFactory;

  Future<String> _runTool(AgentToolCall call) =>
      (_executeTool ?? _executor!.execute)(call);

  Future<bool> isReady() async {
    if (!await _agentSettings.hasConsent()) return false;
    return _credentials.isEnabled();
  }

  /// Same provider/credentials as AI Assist, but with the Fitty Agent model
  /// preference (or the cheaper agent default) overlaid.
  Future<AiSelection?> selectionForAgent() async {
    final base = await _credentials.readSelection();
    if (base == null) return null;
    return _withAgentModel(base);
  }

  Future<AiSelection> _withAgentModel(AiSelection base) async {
    final curated = AiModelCatalogue.forProvider(base.provider);
    if (curated.isEmpty) {
      // ownServer: keep whatever model Assist already configured.
      return base;
    }
    final stored = await _agentSettings.readModel(provider: base.provider);
    final resolved = AiModelCatalogue.resolveForAgent(base.provider, stored);
    return AiSelection(
      provider: base.provider,
      apiKey: base.apiKey,
      endpoint: base.endpoint,
      modelId: resolved?.id ?? base.modelId,
    );
  }

  Future<AgentTurnResult> send({
    required String userText,
    required List<AgentMessage> history,
    List<AgentAttachedImage> images = const [],
  }) async {
    if (!await _agentSettings.hasConsent()) {
      throw const FittyAgentConsentRequiredException();
    }
    final base = await _credentials.readSelection();
    if (base == null || !await _credentials.isEnabled()) {
      throw const FittyAgentNotConfiguredException();
    }

    final selection = await _withAgentModel(base);
    final api = (_apiFactory ?? agentLlmApiFor)(_http, selection);
    final today = DateTime.now().toParsedDay();
    final system = '$fittyAgentSystemPrompt\nToday\'s date is $today.';

    final userMessage = AgentUserMessage(userText, images: images);
    final withUser = [...history, userMessage];
    final result = await api.runTurn(
      system: system,
      history: withUser,
      tools: fittyAgentTools,
      executeTool: _runTool,
    );

    return AgentTurnResult(
      reply: result.reply,
      newMessages: [userMessage, ...result.newMessages],
    );
  }

  MealInterpreterFailure? failureOf(Object error) {
    if (error is MealInterpreterException) return error.failure;
    return null;
  }
}
