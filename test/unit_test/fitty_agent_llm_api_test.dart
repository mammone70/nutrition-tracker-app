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

    test('serializes user message image as base64 content block before text', () async {
      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Plan updated.'},
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
      const bytes = [9, 8, 7];
      await api.runTurn(
        system: 'sys',
        history: [
          AgentUserMessage(
            'Update dinner',
            images: [
              AgentAttachedImage(bytes: bytes, mediaType: 'image/webp'),
            ],
          ),
        ],
        tools: tools,
        executeTool: (_) async => '{}',
      );

      final body = jsonDecode(seen!.body) as Map<String, dynamic>;
      final messages = body['messages'] as List;
      final content = (messages.first as Map)['content'] as List;
      expect(content, hasLength(2));
      expect(content[0], {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': 'image/webp',
          'data': base64Encode(bytes),
        },
      });
      expect(content[1], {'type': 'text', 'text': 'Update dinner'});
    });

    test('sends multiple meal photos as image content blocks', () async {
      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Got both photos.'},
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
      const first = [1, 2];
      const second = [3, 4, 5];
      await api.runTurn(
        system: 'sys',
        history: [
          AgentUserMessage(
            'Update from these',
            images: [
              AgentAttachedImage(bytes: first, mediaType: 'image/webp'),
              AgentAttachedImage(bytes: second, mediaType: 'image/jpeg'),
            ],
          ),
        ],
        tools: tools,
        executeTool: (_) async => '{}',
      );

      final body = jsonDecode(seen!.body) as Map<String, dynamic>;
      final messages = body['messages'] as List;
      final content = (messages.first as Map)['content'] as List;
      expect(content, hasLength(3));
      expect(content[0]['type'], 'image');
      expect(content[1]['type'], 'image');
      expect(content[2], {'type': 'text', 'text': 'Update from these'});
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
                  'type': 'reasoning',
                  'id': 'rs_1',
                  'summary': [
                    {'type': 'summary_text', 'text': 'checking sync'},
                  ],
                },
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
        // store:false — no previous_response_id; full transcript is resent.
        expect(body.containsKey('previous_response_id'), isFalse);
        final input = body['input'] as List;
        expect(input.any((e) => e is Map && e['type'] == 'reasoning'), isTrue);
        expect(
          input.any(
            (e) =>
                e is Map &&
                e['type'] == 'function_call' &&
                e['call_id'] == 'call_1',
          ),
          isTrue,
        );
        expect(
          input.any(
            (e) =>
                e is Map &&
                e['type'] == 'function_call_output' &&
                e['call_id'] == 'call_1',
          ),
          isTrue,
        );
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

    test('serializes user message image as input_image data URL', () async {
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
                  {'type': 'output_text', 'text': 'Updated breakfast.'},
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
      const bytes = [1, 2, 3, 4];
      await api.runTurn(
        system: 'sys',
        history: [
          AgentUserMessage(
            'Add this to my meal plan',
            images: [
              AgentAttachedImage(bytes: bytes, mediaType: 'image/webp'),
            ],
          ),
        ],
        tools: tools,
        executeTool: (_) async => '{}',
      );

      final body = jsonDecode(seen!.body) as Map<String, dynamic>;
      final input = body['input'] as List;
      expect(input, hasLength(1));
      final content = (input.first as Map)['content'] as List;
      expect(content, hasLength(2));
      expect(content[0], {
        'type': 'input_image',
        'image_url': 'data:image/webp;base64,${base64Encode(bytes)}',
      });
      expect(content[1], {
        'type': 'input_text',
        'text': 'Add this to my meal plan',
      });
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
