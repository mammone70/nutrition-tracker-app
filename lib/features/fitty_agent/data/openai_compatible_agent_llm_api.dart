import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_llm_api.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_tool.dart';
import 'package:opennutritracker/features/add_meal/domain/meal_interpreter_exception.dart';

/// OpenAI-compatible Chat Completions multi-turn tool loop.
///
/// Used for OpenAI (direct), OpenRouter, and a server the user runs — the
/// same wire family as meal assist's compatible client, with an agent loop
/// instead of a single forced tool call.
class OpenAiCompatibleAgentLlmApi implements AgentLlmApi {
  static final _log = Logger('OpenAiCompatibleAgentLlmApi');
  static const _maxTokens = 4096;
  static const defaultTimeout = Duration(seconds: 60);

  static final openAiEndpoint = Uri.parse(
    'https://api.openai.com/v1/chat/completions',
  );
  static final openRouterEndpoint = Uri.parse(
    'https://openrouter.ai/api/v1/chat/completions',
  );

  final http.Client _client;
  final String Function()? _apiKey;
  final Uri endpoint;
  final String model;
  final Duration timeout;
  final List<String>? openRouterProviders;
  final bool openRouter;
  final bool storeFalse;

  OpenAiCompatibleAgentLlmApi(
    this._client,
    this._apiKey, {
    required this.endpoint,
    required this.model,
    this.timeout = defaultTimeout,
    this.openRouterProviders,
    this.openRouter = false,
    this.storeFalse = false,
  });

  factory OpenAiCompatibleAgentLlmApi.openAi(
    http.Client client,
    String Function() apiKey, {
    required String model,
    Duration timeout = defaultTimeout,
  }) => OpenAiCompatibleAgentLlmApi(
    client,
    apiKey,
    endpoint: openAiEndpoint,
    model: model,
    timeout: timeout,
    storeFalse: true,
  );

  factory OpenAiCompatibleAgentLlmApi.openRouter(
    http.Client client,
    String Function() apiKey, {
    required String model,
    List<String>? providers,
    Duration timeout = defaultTimeout,
  }) => OpenAiCompatibleAgentLlmApi(
    client,
    apiKey,
    endpoint: openRouterEndpoint,
    model: model,
    timeout: timeout,
    openRouter: true,
    openRouterProviders: providers,
  );

  @override
  Future<AgentTurnResult> runTurn({
    required String system,
    required List<AgentMessage> history,
    required List<AgentToolDefinition> tools,
    required Future<String> Function(AgentToolCall call) executeTool,
    int maxRounds = 8,
  }) async {
    final working = List<AgentMessage>.from(history);
    final added = <AgentMessage>[];

    for (var round = 0; round < maxRounds; round++) {
      final response = await _post(
        system: system,
        messages: working,
        tools: tools,
      );
      final parsed = _parseAssistant(response);
      working.add(parsed);
      added.add(parsed);

      if (parsed.toolCalls.isEmpty) {
        final text = parsed.text?.trim() ?? '';
        if (text.isEmpty) {
          throw const MealInterpreterException(
            'empty agent reply',
            failure: MealInterpreterFailure.unsupported,
          );
        }
        return AgentTurnResult(reply: text, newMessages: added);
      }

      for (final call in parsed.toolCalls) {
        final content = await executeTool(call);
        final result = AgentToolResultMessage(
          toolCallId: call.id,
          name: call.name,
          content: content,
        );
        working.add(result);
        added.add(result);
      }
    }

    throw const MealInterpreterException(
      'agent tool loop exceeded max rounds',
      failure: MealInterpreterFailure.transient,
    );
  }

  Future<String> _post({
    required String system,
    required List<AgentMessage> messages,
    required List<AgentToolDefinition> tools,
  }) async {
    final payload = <String, dynamic>{
      'model': model,
      'max_tokens': _maxTokens,
      'messages': [
        {'role': 'system', 'content': system},
        ..._toChatMessages(messages),
      ],
      'tools': tools
          .map(
            (t) => {
              'type': 'function',
              'function': {
                'name': t.name,
                'description': t.description,
                'parameters': t.parameters,
              },
            },
          )
          .toList(),
    };
    if (storeFalse) {
      // OpenAI Chat Completions also accepts store; keep retention off.
      payload['store'] = false;
    }
    if (openRouter) {
      payload['provider'] = {
        if (openRouterProviders != null) 'order': openRouterProviders,
        'allow_fallbacks': false,
        'data_collection': 'deny',
      };
    }

    final headers = <String, String>{
      'content-type': 'application/json',
      if (_apiKey != null) 'authorization': 'Bearer ${_apiKey()}',
      if (openRouter) 'x-openrouter-metadata': 'enabled',
    };

    final http.Response response;
    try {
      response = await _client
          .post(endpoint, headers: headers, body: jsonEncode(payload))
          .timeout(timeout);
    } catch (_) {
      throw const MealInterpreterException('request failed');
    }

    if (response.statusCode != 200) {
      _log.warning('Agent call failed with ${response.statusCode}');
      throw MealInterpreterException(
        'provider returned ${response.statusCode}',
        failure: _failureFor(response.statusCode),
        statusCode: response.statusCode,
      );
    }
    return response.body;
  }

  static MealInterpreterFailure _failureFor(int statusCode) =>
      switch (statusCode) {
        401 || 403 => MealInterpreterFailure.auth,
        400 || 422 => MealInterpreterFailure.rejected,
        402 => MealInterpreterFailure.billing,
        404 => MealInterpreterFailure.unsupported,
        _ => MealInterpreterFailure.transient,
      };

  List<Map<String, dynamic>> _toChatMessages(List<AgentMessage> messages) {
    final out = <Map<String, dynamic>>[];
    for (final message in messages) {
      switch (message) {
        case AgentUserMessage(:final text):
          out.add({'role': 'user', 'content': text});
        case AgentAssistantMessage(:final text, :final toolCalls):
          out.add({
            'role': 'assistant',
            'content': text,
            if (toolCalls.isNotEmpty)
              'tool_calls': toolCalls
                  .map(
                    (c) => {
                      'id': c.id,
                      'type': 'function',
                      'function': {
                        'name': c.name,
                        'arguments': jsonEncode(c.arguments),
                      },
                    },
                  )
                  .toList(),
          });
        case AgentToolResultMessage(:final toolCallId, :final content):
          out.add({
            'role': 'tool',
            'tool_call_id': toolCallId,
            'content': content,
          });
      }
    }
    return out;
  }

  AgentAssistantMessage _parseAssistant(String body) {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const MealInterpreterException('malformed response');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const MealInterpreterException('response has no choices');
    }
    final first = choices.first;
    if (first is! Map) {
      throw const MealInterpreterException('malformed choice');
    }
    final message = first['message'];
    if (message is! Map) {
      throw const MealInterpreterException('response has no message');
    }

    final content = message['content'];
    final text = content is String ? content : null;
    final calls = <AgentToolCall>[];
    final toolCalls = message['tool_calls'];
    if (toolCalls is List) {
      for (final raw in toolCalls) {
        if (raw is! Map) continue;
        final id = raw['id'];
        final fn = raw['function'];
        if (id is! String || fn is! Map) continue;
        final name = fn['name'];
        if (name is! String) continue;
        final argsRaw = fn['arguments'];
        Map<String, dynamic> args = {};
        if (argsRaw is String && argsRaw.isNotEmpty) {
          try {
            final decodedArgs = jsonDecode(argsRaw);
            if (decodedArgs is Map) {
              args = Map<String, dynamic>.from(decodedArgs);
            }
          } catch (_) {
            args = {};
          }
        } else if (argsRaw is Map) {
          args = Map<String, dynamic>.from(argsRaw);
        }
        calls.add(AgentToolCall(id: id, name: name, arguments: args));
      }
    }

    return AgentAssistantMessage(text: text, toolCalls: calls);
  }
}
