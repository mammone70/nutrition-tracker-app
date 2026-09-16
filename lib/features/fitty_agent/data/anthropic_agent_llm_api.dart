import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_llm_api.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_tool.dart';
import 'package:opennutritracker/features/add_meal/domain/meal_interpreter_exception.dart';

/// Anthropic Messages API multi-turn tool loop for Fitty Agent.
class AnthropicAgentLlmApi implements AgentLlmApi {
  static final _log = Logger('AnthropicAgentLlmApi');
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';
  static const _maxTokens = 4096;
  static const defaultTimeout = Duration(seconds: 60);

  final http.Client _client;
  final String Function() _apiKey;
  final String model;
  final Duration timeout;

  AnthropicAgentLlmApi(
    this._client,
    this._apiKey, {
    required this.model,
    this.timeout = defaultTimeout,
  });

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
      working.add(parsed.message);
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

      for (final call in parsed.message.toolCalls) {
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
    final body = jsonEncode({
      'model': model,
      'max_tokens': _maxTokens,
      'system': system,
      'tools': tools
          .map(
            (t) => {
              'name': t.name,
              'description': t.description,
              'input_schema': t.parameters,
            },
          )
          .toList(),
      'messages': _toAnthropicMessages(messages),
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': _apiKey(),
              'anthropic-version': _apiVersion,
            },
            body: body,
          )
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

  List<Map<String, dynamic>> _toAnthropicMessages(List<AgentMessage> messages) {
    final out = <Map<String, dynamic>>[];
    for (final message in messages) {
      switch (message) {
        case AgentUserMessage(:final text):
          out.add({'role': 'user', 'content': text});
        case AgentAssistantMessage(:final text, :final toolCalls):
          final content = <Map<String, dynamic>>[];
          if (text != null && text.isNotEmpty) {
            content.add({'type': 'text', 'text': text});
          }
          for (final call in toolCalls) {
            content.add({
              'type': 'tool_use',
              'id': call.id,
              'name': call.name,
              'input': call.arguments,
            });
          }
          out.add({'role': 'assistant', 'content': content});
        case AgentToolResultMessage(:final toolCallId, :final content):
          // Anthropic wants tool results as user content blocks. Adjacent
          // tool results are merged into one user message.
          if (out.isNotEmpty &&
              out.last['role'] == 'user' &&
              out.last['content'] is List) {
            (out.last['content'] as List).add({
              'type': 'tool_result',
              'tool_use_id': toolCallId,
              'content': content,
            });
          } else {
            out.add({
              'role': 'user',
              'content': [
                {
                  'type': 'tool_result',
                  'tool_use_id': toolCallId,
                  'content': content,
                },
              ],
            });
          }
      }
    }
    return out;
  }

  ({AgentAssistantMessage message}) _parseAssistant(String body) {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const MealInterpreterException('malformed response');
    }
    final content = decoded['content'];
    if (content is! List) {
      throw const MealInterpreterException('response has no content');
    }

    final buffer = StringBuffer();
    final calls = <AgentToolCall>[];
    for (final block in content) {
      if (block is! Map) continue;
      final type = block['type'];
      if (type == 'text') {
        final text = block['text'];
        if (text is String) buffer.write(text);
      } else if (type == 'tool_use') {
        final id = block['id'];
        final name = block['name'];
        final input = block['input'];
        if (id is! String || name is! String) continue;
        calls.add(
          AgentToolCall(
            id: id,
            name: name,
            arguments: input is Map
                ? Map<String, dynamic>.from(input)
                : <String, dynamic>{},
          ),
        );
      }
    }

    return (
      message: AgentAssistantMessage(
        text: buffer.isEmpty ? null : buffer.toString(),
        toolCalls: calls,
      ),
    );
  }
}
