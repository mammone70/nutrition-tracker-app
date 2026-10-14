import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/add_meal/data/openai_compatible_meal_items_api.dart';
import 'package:opennutritracker/features/add_meal/domain/meal_items_api.dart';
import 'package:opennutritracker/features/nutrition_label/domain/nutrition_label_api.dart';
import 'package:opennutritracker/features/nutrition_label/domain/nutrition_label_entity.dart';
import 'package:opennutritracker/features/nutrition_label/domain/nutrition_label_parser.dart';

/// Wire format variants used by the providers meal assist already speaks.
enum NutritionLabelWireFormat {
  /// Anthropic Messages API.
  anthropic,

  /// OpenAI Responses API (direct OpenAI and some OpenRouter OpenAI models).
  openAiResponses,

  /// OpenAI-compatible Chat Completions (OpenRouter Anthropic rows, own server).
  openAiCompatible,
}

/// Forced-tool nutrition-label reader shared by every AI destination.
///
/// Parallel to the meal-items clients, but with [nutritionLabelToolSchema]
/// instead of [mealItemsToolSchema]. Meal assist stays free of nutrition
/// fields; this path exists specifically to transcribe a printed panel.
class NutritionLabelLlmApi implements NutritionLabelApi {
  static final _log = Logger('NutritionLabelLlmApi');

  static const anthropicEndpoint = 'https://api.anthropic.com/v1/messages';
  static const openAiEndpoint = 'https://api.openai.com/v1/responses';
  static const openRouterChatEndpoint =
      'https://openrouter.ai/api/v1/chat/completions';
  static const openRouterResponsesEndpoint =
      'https://openrouter.ai/api/v1/responses';
  static const _apiVersion = '2023-06-01';
  static const _maxTokens = 1024;
  static const defaultTimeout = Duration(seconds: 30);

  final http.Client _client;
  final String Function()? _apiKey;
  final String model;
  final Uri endpoint;
  final NutritionLabelWireFormat format;
  final Duration timeout;
  final ToolChoiceMode toolChoice;
  final List<String>? openRouterProviders;
  final MealInterpreterFailure timeoutFailure;

  NutritionLabelLlmApi(
    this._client,
    this._apiKey, {
    required this.model,
    required this.endpoint,
    required this.format,
    this.timeout = defaultTimeout,
    this.toolChoice = ToolChoiceMode.namedFunction,
    this.openRouterProviders,
    this.timeoutFailure = MealInterpreterFailure.transient,
  });

  factory NutritionLabelLlmApi.anthropic(
    http.Client client,
    String Function() apiKey, {
    required String model,
    Duration timeout = defaultTimeout,
  }) => NutritionLabelLlmApi(
    client,
    apiKey,
    model: model,
    endpoint: Uri.parse(anthropicEndpoint),
    format: NutritionLabelWireFormat.anthropic,
    timeout: timeout,
  );

  factory NutritionLabelLlmApi.openAi(
    http.Client client,
    String Function() apiKey, {
    required String model,
    Duration timeout = defaultTimeout,
  }) => NutritionLabelLlmApi(
    client,
    apiKey,
    model: model,
    endpoint: Uri.parse(openAiEndpoint),
    format: NutritionLabelWireFormat.openAiResponses,
    timeout: timeout,
  );

  factory NutritionLabelLlmApi.openRouterChat(
    http.Client client,
    String Function() apiKey, {
    required String model,
    List<String>? providers,
    Duration timeout = defaultTimeout,
  }) => NutritionLabelLlmApi(
    client,
    apiKey,
    model: model,
    endpoint: Uri.parse(openRouterChatEndpoint),
    format: NutritionLabelWireFormat.openAiCompatible,
    timeout: timeout,
    openRouterProviders: providers,
  );

  factory NutritionLabelLlmApi.openRouterResponses(
    http.Client client,
    String Function() apiKey, {
    required String model,
    List<String>? providers,
    Duration timeout = defaultTimeout,
  }) => NutritionLabelLlmApi(
    client,
    apiKey,
    model: model,
    endpoint: Uri.parse(openRouterResponsesEndpoint),
    format: NutritionLabelWireFormat.openAiResponses,
    timeout: timeout,
    openRouterProviders: providers,
  );

  factory NutritionLabelLlmApi.ownServer(
    http.Client client,
    String Function()? apiKey, {
    required String model,
    required Uri endpoint,
    Duration? timeout,
  }) => NutritionLabelLlmApi(
    client,
    apiKey,
    model: model,
    endpoint: endpoint,
    format: NutritionLabelWireFormat.openAiCompatible,
    timeout: timeout ?? const Duration(seconds: 120),
    toolChoice: ToolChoiceMode.anyTool,
    timeoutFailure: MealInterpreterFailure.timeout,
  );

  @override
  Future<NutritionLabelEntity> requestLabel({
    required MealPhotoContent content,
    required String system,
  }) async {
    final body = switch (format) {
      NutritionLabelWireFormat.anthropic => _anthropicBody(content, system),
      NutritionLabelWireFormat.openAiResponses => _responsesBody(
        content,
        system,
      ),
      NutritionLabelWireFormat.openAiCompatible => _compatibleBody(
        content,
        system,
      ),
    };

    final http.Response response;
    try {
      response = await _client
          .post(endpoint, headers: _headers(), body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw MealInterpreterException(
        'request timed out',
        failure: timeoutFailure,
      );
    } catch (_) {
      throw const MealInterpreterException('request failed');
    }

    if (response.statusCode != 200) {
      _log.warning('Label read failed with ${response.statusCode}');
      throw MealInterpreterException(
        'provider returned ${response.statusCode}',
        failure: _failureFor(response.statusCode),
        statusCode: response.statusCode,
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const MealInterpreterException('malformed response');
    }

    final input = switch (format) {
      NutritionLabelWireFormat.anthropic => _anthropicToolInput(decoded),
      NutritionLabelWireFormat.openAiResponses => _responsesToolInput(decoded),
      NutritionLabelWireFormat.openAiCompatible => _compatibleToolInput(
        decoded,
      ),
    };

    return nutritionLabelFromJson(input);
  }

  Map<String, String> _headers() {
    final key = _apiKey?.call();
    return switch (format) {
      NutritionLabelWireFormat.anthropic => {
        'content-type': 'application/json',
        'x-api-key': key ?? '',
        'anthropic-version': _apiVersion,
      },
      NutritionLabelWireFormat.openAiResponses ||
      NutritionLabelWireFormat.openAiCompatible => {
        'content-type': 'application/json',
        if (key != null && key.isNotEmpty) 'authorization': 'Bearer $key',
      },
    };
  }

  String _anthropicBody(MealPhotoContent content, String system) => jsonEncode({
    'model': model,
    'max_tokens': _maxTokens,
    'system': system,
    'tools': [
      {
        'name': nutritionLabelToolName,
        'description': nutritionLabelToolDescription,
        'input_schema': nutritionLabelToolSchema,
      },
    ],
    'tool_choice': {'type': 'tool', 'name': nutritionLabelToolName},
    'messages': [
      {
        'role': 'user',
        'content': [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': content.mediaType,
              'data': content.base64Data,
            },
          },
          {'type': 'text', 'text': nutritionLabelPhotoPrompt},
        ],
      },
    ],
  });

  String _responsesBody(MealPhotoContent content, String system) => jsonEncode({
    'model': model,
    'instructions': system,
    'input': [
      {
        'role': 'user',
        'content': [
          {
            'type': 'input_image',
            'image_url':
                'data:${content.mediaType};base64,${content.base64Data}',
          },
          {'type': 'input_text', 'text': nutritionLabelPhotoPrompt},
        ],
      },
    ],
    'tools': [
      {
        'type': 'function',
        'name': nutritionLabelToolName,
        'description': nutritionLabelToolDescription,
        'parameters': nutritionLabelToolSchema,
        'strict': false,
      },
    ],
    'tool_choice': {'type': 'function', 'name': nutritionLabelToolName},
    'store': false,
    'max_output_tokens': _maxTokens,
    if (openRouterProviders != null)
      'provider': {
        'require_parameters': true,
        'data_collection': 'deny',
        'only': openRouterProviders,
        'allow_fallbacks': false,
      },
  });

  String _compatibleBody(MealPhotoContent content, String system) => jsonEncode(
    {
      'model': model,
      'max_tokens': _maxTokens,
      'messages': [
        {'role': 'system', 'content': system},
        {
          'role': 'user',
          'content': [
            // OpenRouter image docs prefer text first; Anthropic prefers
            // the opposite. This path is the OpenAI-compatible one.
            {'type': 'text', 'text': nutritionLabelPhotoPrompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${content.mediaType};base64,${content.base64Data}',
              },
            },
          ],
        },
      ],
      'tools': [
        {
          'type': 'function',
          'function': {
            'name': nutritionLabelToolName,
            'description': nutritionLabelToolDescription,
            'parameters': nutritionLabelToolSchema,
          },
        },
      ],
      if (toolChoice == ToolChoiceMode.namedFunction)
        'tool_choice': {
          'type': 'function',
          'function': {'name': nutritionLabelToolName},
        }
      else if (toolChoice == ToolChoiceMode.anyTool)
        'tool_choice': 'required',
      if (openRouterProviders != null)
        'provider': {
          'require_parameters': true,
          'data_collection': 'deny',
          'only': openRouterProviders,
          'allow_fallbacks': false,
        },
    },
  );

  Object? _anthropicToolInput(Map<String, dynamic> decoded) {
    final content = decoded['content'];
    if (content is! List) {
      throw const MealInterpreterException('response has no content');
    }
    for (final block in content) {
      if (block is! Map) continue;
      if (block['type'] != 'tool_use') continue;
      if (block['name'] != nutritionLabelToolName) continue;
      return block['input'];
    }
    throw const MealInterpreterException(
      'response has no tool call',
      failure: MealInterpreterFailure.unsupported,
    );
  }

  Object? _responsesToolInput(Map<String, dynamic> decoded) {
    final output = decoded['output'];
    if (output is! List) {
      throw const MealInterpreterException('response has no output');
    }
    for (final item in output) {
      if (item is! Map) continue;
      if (item['type'] != 'function_call') continue;
      if (item['name'] != nutritionLabelToolName) continue;
      final args = item['arguments'];
      if (args is String) {
        try {
          return jsonDecode(args);
        } catch (_) {
          throw const MealInterpreterException('malformed tool arguments');
        }
      }
      return args;
    }
    throw const MealInterpreterException(
      'response has no tool call',
      failure: MealInterpreterFailure.unsupported,
    );
  }

  Object? _compatibleToolInput(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const MealInterpreterException('response has no choices');
    }
    final message = choices.first is Map ? choices.first['message'] : null;
    if (message is! Map) {
      throw const MealInterpreterException('response has no message');
    }
    final toolCalls = message['tool_calls'];
    if (toolCalls is! List || toolCalls.isEmpty) {
      throw const MealInterpreterException(
        'response has no tool call',
        failure: MealInterpreterFailure.unsupported,
      );
    }
    for (final call in toolCalls) {
      if (call is! Map) continue;
      final function = call['function'];
      if (function is! Map) continue;
      if (function['name'] != nutritionLabelToolName) continue;
      final args = function['arguments'];
      if (args is String) {
        try {
          return jsonDecode(args);
        } catch (_) {
          throw const MealInterpreterException('malformed tool arguments');
        }
      }
      return args;
    }
    throw const MealInterpreterException(
      'response has no tool call',
      failure: MealInterpreterFailure.unsupported,
    );
  }

  static MealInterpreterFailure _failureFor(int statusCode) =>
      switch (statusCode) {
        401 || 403 => MealInterpreterFailure.auth,
        400 || 422 => MealInterpreterFailure.rejected,
        402 => MealInterpreterFailure.billing,
        404 => MealInterpreterFailure.unsupported,
        _ => MealInterpreterFailure.transient,
      };
}
