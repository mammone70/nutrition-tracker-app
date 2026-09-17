import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/add_meal/domain/meal_interpreter_exception.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';
import 'package:opennutritracker/features/fitty_agent/domain/fitty_agent_consent_storage.dart';
import 'package:opennutritracker/features/fitty_agent/domain/run_fitty_agent_usecase.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_event.dart';
import 'package:opennutritracker/features/fitty_agent/presentation/fitty_agent_state.dart';
import 'package:opennutritracker/core/utils/ai_credential_storage.dart';

class FittyAgentBloc extends Bloc<FittyAgentEvent, FittyAgentState> {
  static final _log = Logger('FittyAgentBloc');

  final RunFittyAgentUseCase _runAgent;
  final FittyAgentConsentStorage _consent;
  final AiCredentialStorage _credentials;

  final List<AgentMessage> _history = [];

  FittyAgentBloc({
    required RunFittyAgentUseCase runAgent,
    required FittyAgentConsentStorage consent,
    required AiCredentialStorage credentials,
  }) : _runAgent = runAgent,
       _consent = consent,
       _credentials = credentials,
       super(const FittyAgentInitial()) {
    on<FittyAgentStarted>(_onStarted);
    on<FittyAgentConsentAccepted>(_onConsentAccepted);
    on<FittyAgentMessageSubmitted>(_onSubmitted);
    on<FittyAgentCleared>(_onCleared);
  }

  Future<void> _onStarted(
    FittyAgentStarted event,
    Emitter<FittyAgentState> emit,
  ) async {
    final hasConsent = await _consent.hasConsent();
    final aiEnabled = await _credentials.isEnabled();
    if (!hasConsent || !aiEnabled) {
      emit(
        FittyAgentNeedsSetup(
          needsAiConfig: !aiEnabled,
          needsConsent: !hasConsent,
        ),
      );
      return;
    }
    emit(const FittyAgentReady(bubbles: []));
  }

  Future<void> _onConsentAccepted(
    FittyAgentConsentAccepted event,
    Emitter<FittyAgentState> emit,
  ) async {
    await _consent.setConsent(true);
    add(const FittyAgentStarted());
  }

  Future<void> _onSubmitted(
    FittyAgentMessageSubmitted event,
    Emitter<FittyAgentState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty) return;

    final current = state;
    if (current is! FittyAgentReady || current.sending) return;

    final bubbles = [
      ...current.bubbles,
      AgentChatBubble(fromUser: true, text: text),
    ];
    emit(current.copyWith(bubbles: bubbles, sending: true, clearError: true));

    try {
      final result = await _runAgent.send(userText: text, history: _history);
      _history.addAll(result.newMessages);

      final nextBubbles = [...bubbles];
      for (final message in result.newMessages) {
        if (message is AgentToolResultMessage) {
          nextBubbles.add(
            AgentChatBubble(
              fromUser: false,
              text: 'Used ${message.name}',
              isToolActivity: true,
            ),
          );
        }
      }
      nextBubbles.add(AgentChatBubble(fromUser: false, text: result.reply));
      emit(FittyAgentReady(bubbles: nextBubbles));
    } on FittyAgentNotConfiguredException {
      emit(
        const FittyAgentNeedsSetup(needsAiConfig: true, needsConsent: false),
      );
    } on FittyAgentConsentRequiredException {
      emit(
        const FittyAgentNeedsSetup(needsAiConfig: false, needsConsent: true),
      );
    } catch (e, st) {
      _log.warning('Fitty Agent turn failed', e, st);
      final failure = e is MealInterpreterException ? e.failure : null;
      final detail = e is MealInterpreterException ? e.reason : null;
      emit(
        FittyAgentReady(
          bubbles: bubbles,
          errorMessage: _errorLabel(failure, detail),
        ),
      );
    }
  }

  Future<void> _onCleared(
    FittyAgentCleared event,
    Emitter<FittyAgentState> emit,
  ) async {
    _history.clear();
    if (state is FittyAgentReady) {
      emit(const FittyAgentReady(bubbles: []));
    }
  }

  String _errorLabel(MealInterpreterFailure? failure, String? detail) {
    if (detail != null && detail.contains('exceeded max rounds')) {
      return 'That request needed too many steps. Try asking for fewer '
          'changes at once, or say “set my weekly macros” with high/low days.';
    }
    final trimmed = detail?.trim();
    final hasDetail = trimmed != null && trimmed.isNotEmpty;
    // Prefer a specific reason over the generic "connection" line whenever we
    // have one — parse failures and 5xx used to look like offline blips.
    final specific = switch (failure) {
      MealInterpreterFailure.auth => 'Authentication failed. Check AI Assist.',
      MealInterpreterFailure.billing => 'Provider billing error.',
      MealInterpreterFailure.unsupported =>
        hasDetail
            ? trimmed
            : 'This model does not support agent tools. Try another model '
                  'under Fitty Agent → model.',
      MealInterpreterFailure.timeout =>
        'The model took too long to answer. Try again.',
      MealInterpreterFailure.rejected =>
        hasDetail
            ? trimmed
            : 'The provider rejected the request. Try another Fitty Chat '
                  'model, or check AI Assist settings.',
      MealInterpreterFailure.insecureDestination =>
        'That server address is not allowed for plaintext requests.',
      MealInterpreterFailure.transient =>
        hasDetail
            ? 'Request failed ($trimmed). Try again.'
            : 'Something went wrong. Check your connection and try again.',
      null =>
        hasDetail
            ? 'Something went wrong ($trimmed).'
            : 'Something went wrong. Check your connection and try again.',
    };
    return specific;
  }
}
