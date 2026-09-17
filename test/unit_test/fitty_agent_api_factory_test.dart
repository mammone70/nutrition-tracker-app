import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/features/fitty_agent/data/agent_llm_api_factory.dart';
import 'package:opennutritracker/features/fitty_agent/data/openai_agent_llm_api.dart';
import 'package:opennutritracker/features/fitty_agent/data/openai_compatible_agent_llm_api.dart';

void main() {
  test('OpenRouter OpenAI models use the Responses API', () {
    final api = agentLlmApiFor(
      MockClient((_) async => http.Response('{}', 200)),
      const AiSelection(
        provider: AiProvider.openrouter,
        apiKey: 'sk-or',
        modelId: 'openai/gpt-5.6-luna',
      ),
    );
    expect(api, isA<OpenAiAgentLlmApi>());
    final responses = api as OpenAiAgentLlmApi;
    expect(responses.endpoint, OpenAiAgentLlmApi.openRouterEndpoint);
    expect(responses.openRouter, isTrue);
    expect(responses.openRouterProviders, ['openai']);
  });

  test('OpenRouter Anthropic models stay on Chat Completions', () {
    final api = agentLlmApiFor(
      MockClient((_) async => http.Response('{}', 200)),
      const AiSelection(
        provider: AiProvider.openrouter,
        apiKey: 'sk-or',
        modelId: 'anthropic/claude-sonnet-5',
      ),
    );
    expect(api, isA<OpenAiCompatibleAgentLlmApi>());
  });

  test('direct OpenAI still uses api.openai.com Responses', () {
    final api = agentLlmApiFor(
      MockClient((_) async => http.Response('{}', 200)),
      const AiSelection(
        provider: AiProvider.openai,
        apiKey: 'sk-test',
        modelId: 'gpt-5.6-luna',
      ),
    );
    expect(api, isA<OpenAiAgentLlmApi>());
    final responses = api as OpenAiAgentLlmApi;
    expect(responses.endpoint, OpenAiAgentLlmApi.openAiEndpoint);
    expect(responses.openRouter, isFalse);
  });
}
