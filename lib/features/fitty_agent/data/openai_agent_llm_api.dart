import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/add_meal/domain/meal_interpreter_exception.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_llm_api.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_tool.dart';

/// Responses API multi-turn tool loop for Fitty Agent (OpenAI direct or
/// OpenRouter's OpenAI-compatible `/api/v1/responses`).
///
/// Meal assist uses Responses rather than Chat Completions because from
/// GPT-5.4 tool calling is unsupported on Chat Completions with
/// `reasoning: none` (#681). GPT-5.6 tightened the other direction: tools
/// with a non-`none` reasoning effort also 400 on Chat Completions. The agent
/// must use Responses for OpenAI-served models — including OpenRouter's
/// `openai/*` rows — or those installs fail every tool turn.
class OpenAiAgentLlmApi implements AgentLlmApi {
  static final _log = Logger('OpenAiAgentLlmApi');
  static final openAiEndpoint = Uri.parse(
    'https://api.openai.com/v1/responses',
  );
  static final openRouterEndpoint = Uri.parse(
    'https://openrouter.ai/api/v1/responses',
  );
  static const _maxOutputTokens = 4096;
  static const defaultTimeout = Duration(seconds: 120);

  final http.Client _client;
  final String Function() _apiKey;
  final Uri endpoint;
  final String model;
  final Duration timeout;
  final List<String>? openRouterProviders;
  final bool openRouter;

  OpenAiAgentLlmApi(
    this._client,
    this._apiKey, {
    required this.model,
    Uri? endpoint,
    this.timeout = defaultTimeout,
    this.openRouterProviders,
    this.openRouter = false,
  }) : endpoint = endpoint ?? openAiEndpoint;

  factory OpenAiAgentLlmApi.openRouter(
    http.Client client,
    String Function() apiKey, {
    required String model,
    List<String>? providers,
    Duration timeout = defaultTimeout,
  }) => OpenAiAgentLlmApi(
    client,
    apiKey,
    model: model,
    endpoint: openRouterEndpoint,
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
    int maxRounds = 24,
  }) async {
    final added = <AgentMessage>[];
    // Responses continues a turn with previous_response_id + function outputs
    // rather than resending the whole transcript each time.
    String? previousResponseId;
    List<Map<String, dynamic>>? nextInput = _initialInput(history);

    for (var round = 0; round < maxRounds; round++) {
      final decoded = await _post(
        system: system,
        tools: tools,
        input: nextInput,
        previousResponseId: previousResponseId,
      );
      previousResponseId = decoded['id'] is String
          ? decoded['id'] as String
          : null;

      final parsed = _parseOutput(decoded);
      added.add(parsed.message);

      if (parsed.message.toolCalls.isEmpty) {
        final text = parsed.message.text?.trim() ?? '';
        if (text.isEmpty) {
          throw const MealInterpreterException(
            'empty agent reply',
            failure: MealInterpreterFailure.unsupported,
          );
        }
        return AgentTurnResult(reply: text, newMessages: added);
      }

      final outputs = <Map<String, dynamic>>[];
      for (final call in parsed.message.toolCalls) {
        final content = await executeTool(call);
        added.add(
          AgentToolResultMessage(
            toolCallId: call.id,
            name: call.name,
            content: content,
          ),
        );
        outputs.add({
          'type': 'function_call_output',
          'call_id': call.id,
          'output': content,
        });
      }
      nextInput = outputs;
    }

    throw const MealInterpreterException(
      'agent tool loop exceeded max rounds',
      failure: MealInterpreterFailure.transient,
    );
  }

  List<Map<String, dynamic>> _initialInput(List<AgentMessage> history) {
    final input = <Map<String, dynamic>>[];
    for (final message in history) {
      switch (message) {
        case AgentUserMessage(:final text):
          input.add({
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': text},
            ],
          });
        case AgentAssistantMessage(:final text, :final toolCalls):
          if (text != null && text.isNotEmpty) {
            input.add({
              'role': 'assistant',
              'content': [
                {'type': 'output_text', 'text': text},
              ],
            });
          }
          for (final call in toolCalls) {
            input.add({
              'type': 'function_call',
              'call_id': call.id,
              'name': call.name,
              'arguments': jsonEncode(call.arguments),
            });
          }
        case AgentToolResultMessage(:final toolCallId, :final content):
          input.add({
            'type': 'function_call_output',
            'call_id': toolCallId,
            'output': content,
          });
      }
    }
    return input;
  }

  Future<Map<String, dynamic>> _post({
    required String system,
    required List<AgentToolDefinition> tools,
    required List<Map<String, dynamic>>? input,
    required String? previousResponseId,
  }) async {
    final payload = <String, dynamic>{
      'model': model,
      'instructions': system,
      'tools': tools
          .map(
            (t) => {
              'type': 'function',
              'name': t.name,
              'description': t.description,
              'parameters': t.parameters,
              // Same as meal assist: Responses defaults to strict and would
              // 400 optional fields. Enforcement stays in Dart.
              'strict': false,
            },
          )
          .toList(),
      'store': false,
      'max_output_tokens': _maxOutputTokens,
      if (previousResponseId != null)
        'previous_response_id': previousResponseId,
      if (input != null) 'input': input,
      if (openRouter)
        'provider': {
          'require_parameters': true,
          'data_collection': 'deny',
          if (openRouterProviders != null) ...{
            'only': openRouterProviders,
            'allow_fallbacks': false,
          },
        },
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer ${_apiKey()}',
              if (openRouter) 'x-openrouter-metadata': 'enabled',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const MealInterpreterException(
        'request timed out',
        failure: MealInterpreterFailure.timeout,
      );
    } catch (_) {
      throw const MealInterpreterException('request failed');
    }

    if (response.statusCode != 200) {
      final fields = _errorFields(response.body);
      _log.warning(
        'Agent call failed with ${response.statusCode}'
        '${fields.message == null ? '' : ': ${fields.message}'}',
      );
      throw MealInterpreterException(
        fields.message ?? 'provider returned ${response.statusCode}',
        failure: _failureFor(response.statusCode, fields),
        statusCode: response.statusCode,
      );
    }

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const MealInterpreterException('malformed response');
    }
  }

  ({AgentAssistantMessage message}) _parseOutput(Map<String, dynamic> decoded) {
    final output = decoded['output'];
    if (output is! List) {
      throw const MealInterpreterException('response has no output');
    }

    final buffer = StringBuffer();
    final calls = <AgentToolCall>[];
    for (final entry in output) {
      if (entry is! Map) continue;
      final type = entry['type'];
      if (type == 'message') {
        final content = entry['content'];
        if (content is List) {
          for (final part in content) {
            if (part is! Map) continue;
            if (part['type'] == 'output_text' && part['text'] is String) {
              buffer.write(part['text'] as String);
            }
          }
        }
      } else if (type == 'function_call') {
        final callId = entry['call_id'] ?? entry['id'];
        final name = entry['name'];
        final argsRaw = entry['arguments'];
        if (callId is! String || name is! String) continue;
        Map<String, dynamic> args = {};
        if (argsRaw is String && argsRaw.isNotEmpty) {
          try {
            final parsed = jsonDecode(argsRaw);
            if (parsed is Map) {
              args = Map<String, dynamic>.from(parsed);
            }
          } catch (_) {
            args = {};
          }
        } else if (argsRaw is Map) {
          args = Map<String, dynamic>.from(argsRaw);
        }
        calls.add(AgentToolCall(id: callId, name: name, arguments: args));
      }
    }

    return (
      message: AgentAssistantMessage(
        text: buffer.isEmpty ? null : buffer.toString(),
        toolCalls: calls,
      ),
    );
  }

  static ({String? code, String? type, String? message}) _errorFields(
    String body,
  ) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        return (
          code: error['code'] is String ? error['code'] as String : null,
          type: error['type'] is String ? error['type'] as String : null,
          message: error['message'] is String
              ? error['message'] as String
              : null,
        );
      }
    } catch (_) {}
    return (code: null, type: null, message: null);
  }

  static const _quotaCode = 'insufficient_quota';

  static MealInterpreterFailure _failureFor(
    int statusCode,
    ({String? code, String? type, String? message}) error,
  ) {
    final message = (error.message ?? '').toLowerCase();
    if (message.contains('reasoning') && message.contains('tool')) {
      return MealInterpreterFailure.unsupported;
    }
    return switch (statusCode) {
      401 || 403 => MealInterpreterFailure.auth,
      400 when error.code == 'model_not_found' =>
        MealInterpreterFailure.unsupported,
      400 || 422 => MealInterpreterFailure.rejected,
      402 => MealInterpreterFailure.billing,
      429 when error.code == _quotaCode || error.type == _quotaCode =>
        MealInterpreterFailure.billing,
      404 => MealInterpreterFailure.unsupported,
      _ => MealInterpreterFailure.transient,
    };
  }
}
