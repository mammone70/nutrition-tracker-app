import 'package:http/http.dart' as http;
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/core/utils/ai_model_catalogue.dart';
import 'package:opennutritracker/core/utils/plaintext_destination_guard.dart';
import 'package:opennutritracker/features/add_meal/data/meal_items_api_factory.dart';
import 'package:opennutritracker/features/fitty_agent/data/anthropic_agent_llm_api.dart';
import 'package:opennutritracker/features/fitty_agent/data/openai_agent_llm_api.dart';
import 'package:opennutritracker/features/fitty_agent/data/openai_compatible_agent_llm_api.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_llm_api.dart';

/// Builds an [AgentLlmApi] from the same [AiSelection] meal assist uses.
AgentLlmApi agentLlmApiFor(
  http.Client client,
  AiSelection selection, {
  Duration? timeout,
}) {
  final model = AiModelCatalogue.resolve(selection.provider, selection.modelId);
  final modelId = model?.id ?? selection.modelId;
  if (modelId == null) {
    throw StateError('no model for ${selection.provider.name}');
  }
  String key() => selection.apiKey ?? '';

  return switch (selection.provider) {
    AiProvider.anthropic => AnthropicAgentLlmApi(
      client,
      key,
      model: modelId,
      timeout: timeout ?? AnthropicAgentLlmApi.defaultTimeout,
    ),
    // Responses, not Chat Completions — same reason as meal assist (#681).
    AiProvider.openai => OpenAiAgentLlmApi(
      client,
      key,
      model: modelId,
      timeout: timeout ?? OpenAiAgentLlmApi.defaultTimeout,
    ),
    AiProvider.openrouter => OpenAiCompatibleAgentLlmApi.openRouter(
      client,
      key,
      model: modelId,
      providers: model?.providers,
      timeout: timeout ?? OpenAiCompatibleAgentLlmApi.defaultTimeout,
    ),
    AiProvider.ownServer => () {
      final endpoint = AiCredentialStorage.resolveEndpoint(selection.endpoint!);
      if (endpoint == null) {
        throw StateError('invalid own-server endpoint');
      }
      return OpenAiCompatibleAgentLlmApi(
        GuardedPlaintextClient(client),
        selection.apiKey == null ? null : key,
        endpoint: endpoint,
        model: modelId,
        timeout: timeout ?? ownServerTimeout,
      );
    }(),
  };
}
