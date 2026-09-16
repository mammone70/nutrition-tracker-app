import 'package:http/http.dart' as http;
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
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
  final FittyAgentConsentStorage _consent;
  final http.Client _http;
  final AgentToolExecutor _executor;
  final AgentLlmApi Function(http.Client client, AiSelection selection)?
  _apiFactory;

  RunFittyAgentUseCase({
    required AiCredentialStorage credentials,
    required FittyAgentConsentStorage consent,
    required http.Client httpClient,
    required AgentToolExecutor executor,
    AgentLlmApi Function(http.Client client, AiSelection selection)? apiFactory,
  }) : _credentials = credentials,
       _consent = consent,
       _http = httpClient,
       _executor = executor,
       _apiFactory = apiFactory;

  Future<bool> isReady() async {
    if (!await _consent.hasConsent()) return false;
    return _credentials.isEnabled();
  }

  Future<AgentTurnResult> send({
    required String userText,
    required List<AgentMessage> history,
  }) async {
    if (!await _consent.hasConsent()) {
      throw const FittyAgentConsentRequiredException();
    }
    final selection = await _credentials.readSelection();
    if (selection == null || !await _credentials.isEnabled()) {
      throw const FittyAgentNotConfiguredException();
    }

    final api = (_apiFactory ?? agentLlmApiFor)(_http, selection);
    final today = DateTime.now().toParsedDay();
    final system = '$fittyAgentSystemPrompt\nToday\'s date is $today.';

    final withUser = [...history, AgentUserMessage(userText)];
    final result = await api.runTurn(
      system: system,
      history: withUser,
      tools: fittyAgentTools,
      executeTool: _executor.execute,
    );

    return AgentTurnResult(
      reply: result.reply,
      newMessages: [AgentUserMessage(userText), ...result.newMessages],
    );
  }

  MealInterpreterFailure? failureOf(Object error) {
    if (error is MealInterpreterException) return error.failure;
    return null;
  }
}
