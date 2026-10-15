import 'package:http/http.dart' as http;
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';
import 'package:opennutritracker/core/utils/ai_model_catalogue.dart';
import 'package:opennutritracker/core/utils/plaintext_destination_guard.dart';
import 'package:opennutritracker/features/add_meal/data/meal_items_api_factory.dart';
import 'package:opennutritracker/features/nutrition_label/data/nutrition_label_llm_api.dart';
import 'package:opennutritracker/features/nutrition_label/domain/nutrition_label_api.dart';

/// Builds a [NutritionLabelApi] from the same [AiSelection] meal assist uses.
NutritionLabelApi nutritionLabelApiFor(
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
    AiProvider.anthropic => NutritionLabelLlmApi.anthropic(
      client,
      key,
      model: modelId,
      timeout: timeout ?? NutritionLabelLlmApi.defaultTimeout,
    ),
    AiProvider.openai => NutritionLabelLlmApi.openAi(
      client,
      key,
      model: modelId,
      timeout: timeout ?? NutritionLabelLlmApi.defaultTimeout,
    ),
    AiProvider.openrouter => _openRouter(
      client,
      key,
      model: model,
      modelId: modelId,
      timeout: timeout,
    ),
    AiProvider.ownServer => () {
      final endpoint = AiCredentialStorage.resolveEndpoint(selection.endpoint!);
      if (endpoint == null) {
        throw StateError('invalid own-server endpoint');
      }
      return NutritionLabelLlmApi.ownServer(
        GuardedPlaintextClient(client),
        selection.apiKey == null ? null : key,
        model: modelId,
        endpoint: endpoint,
        timeout: timeout ?? ownServerTimeout,
      );
    }(),
  };
}

NutritionLabelApi _openRouter(
  http.Client client,
  String Function() key, {
  required AiModel? model,
  required String modelId,
  Duration? timeout,
}) {
  // Same split as meal assist / Fitty Agent: OpenAI-served OpenRouter rows
  // need the Responses API; Anthropic rows stay on Chat Completions.
  final needsResponses = model != null
      ? (model.servedBy == 'OpenAI' || model.providers.contains('openai'))
      : (modelId.toLowerCase().startsWith('openai/') ||
            modelId.toLowerCase().contains('gpt-5'));

  if (needsResponses) {
    return NutritionLabelLlmApi.openRouterResponses(
      client,
      key,
      model: modelId,
      providers: model?.providers,
      timeout: timeout ?? NutritionLabelLlmApi.defaultTimeout,
    );
  }
  return NutritionLabelLlmApi.openRouterChat(
    client,
    key,
    model: modelId,
    providers: model?.providers,
    timeout: timeout ?? NutritionLabelLlmApi.defaultTimeout,
  );
}
