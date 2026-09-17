import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/features/fitty_agent/data/anthropic_agent_llm_api.dart';
import 'package:opennutritracker/features/fitty_agent/data/openai_agent_llm_api.dart';
import 'package:opennutritracker/features/fitty_agent/data/openai_compatible_agent_llm_api.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_tool.dart';

void main() {
  final tools = [
    const AgentToolDefinition(
      name: 'get_sync_status',
      description: 'status',
      parameters: {'type': 'object', 'properties': <String, dynamic>{}},
    ),
  ];

  group('AnthropicAgentLlmApi', () {
    test('runs a tool then returns the final text reply', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'type': 'tool_use',
                  'id': 'toolu_1',
                  'name': 'get_sync_status',
                  'input': <String, dynamic>{},
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Sync is configured.'},
            ],
          }),
          200,
        );
      });

      final api = AnthropicAgentLlmApi(
        client,
        () => 'sk-test',
        model: 'claude-haiku-4-5',
      );
      final executed = <String>[];
      final result = await api.runTurn(
        system: 'sys',
        history: const [AgentUserMessage('sync status?')],
        tools: tools,
        executeTool: (call) async {
          executed.add(call.name);
          return jsonEncode({'ok': true, 'configured': true});
        },
      );

      expect(executed, ['get_sync_status']);
      expect(result.reply, 'Sync is configured.');
      expect(calls, 2);
    });
  });

  group('OpenAiCompatibleAgentLlmApi', () {
    test('parses tool_calls and continues the loop', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'role': 'assistant',
                    'content': null,
                    'tool_calls': [
                      {
                        'id': 'call_1',
                        'type': 'function',
                        'function': {
                          'name': 'get_sync_status',
                          'arguments': '{}',
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'All good.'},
              },
            ],
          }),
          200,
        );
      });

      final api = OpenAiCompatibleAgentLlmApi.openRouter(
        client,
        () => 'sk-test',
        model: 'openai/gpt-4.1-mini',
      );
      final result = await api.runTurn(
        system: 'sys',
        history: const [AgentUserMessage('status')],
        tools: tools,
        executeTool: (_) async => '{"ok":true}',
      );

      expect(result.reply, 'All good.');
      expect(calls, 2);
    });

    test('uses max_completion_tokens for gpt-5 models', () async {
      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'ok'},
              },
            ],
          }),
          200,
        );
      });

      final api = OpenAiCompatibleAgentLlmApi.openRouter(
        client,
        () => 'sk-test',
        model: 'openai/gpt-5.6-terra',
      );
      await api.runTurn(
        system: 'sys',
        history: const [AgentUserMessage('hi')],
        tools: tools,
        executeTool: (_) async => '{}',
      );

      final body = jsonDecode(seen!.body) as Map<String, dynamic>;
      expect(body.containsKey('max_completion_tokens'), isTrue);
      expect(body.containsKey('max_tokens'), isFalse);
      expect(body['reasoning'], {'effort': 'none'});
      expect(body['provider'], {
        'require_parameters': true,
        'data_collection': 'deny',
      });
    });
  });

  group('OpenAiAgentLlmApi', () {
    test('runs Responses function_call then returns text', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, '/v1/responses');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['store'], false);
        expect(body['max_output_tokens'], isNotNull);
        final tools = body['tools'] as List;
        expect((tools.first as Map)['strict'], false);

        if (calls == 1) {
          return http.Response(
            jsonEncode({
              'id': 'resp_1',
              'output': [
                {
                  'type': 'function_call',
                  'call_id': 'call_1',
                  'name': 'get_sync_status',
                  'arguments': '{}',
                },
              ],
            }),
            200,
          );
        }
        expect(body['previous_response_id'], 'resp_1');
        return http.Response(
          jsonEncode({
            'id': 'resp_2',
            'output': [
              {
                'type': 'message',
                'content': [
                  {'type': 'output_text', 'text': 'Sync is configured.'},
                ],
              },
            ],
          }),
          200,
        );
      });

      final api = OpenAiAgentLlmApi(
        client,
        () => 'sk-test',
        model: 'gpt-5.6-terra',
      );
      final result = await api.runTurn(
        system: 'sys',
        history: const [AgentUserMessage('status')],
        tools: tools,
        executeTool: (_) async => '{"ok":true}',
      );

      expect(result.reply, 'Sync is configured.');
      expect(calls, 2);
    });

    test(
      'OpenRouter Responses pins openai and uses the broker endpoint',
      () async {
        http.Request? seen;
        final client = MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'id': 'resp_1',
              'output': [
                {
                  'type': 'message',
                  'content': [
                    {'type': 'output_text', 'text': 'ok'},
                  ],
                },
              ],
            }),
            200,
          );
        });

        final api = OpenAiAgentLlmApi.openRouter(
          client,
          () => 'sk-or',
          model: 'openai/gpt-5.6-luna',
          providers: const ['openai'],
        );
        await api.runTurn(
          system: 'sys',
          history: const [AgentUserMessage('hi')],
          tools: tools,
          executeTool: (_) async => '{}',
        );

        expect(seen!.url.host, 'openrouter.ai');
        expect(seen!.url.path, '/api/v1/responses');
        final body = jsonDecode(seen!.body) as Map<String, dynamic>;
        expect(body['provider'], {
          'require_parameters': true,
          'data_collection': 'deny',
          'only': ['openai'],
          'allow_fallbacks': false,
        });
      },
    );
  });
}
