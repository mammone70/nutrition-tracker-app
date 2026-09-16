import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opennutritracker/features/fitty_agent/data/anthropic_agent_llm_api.dart';
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

      final api = OpenAiCompatibleAgentLlmApi.openAi(
        client,
        () => 'sk-test',
        model: 'gpt-4.1-mini',
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
  });
}
