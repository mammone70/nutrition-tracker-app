import 'package:equatable/equatable.dart';

abstract class FittyAgentState extends Equatable {
  const FittyAgentState();

  @override
  List<Object?> get props => [];
}

class FittyAgentInitial extends FittyAgentState {
  const FittyAgentInitial();
}

class FittyAgentNeedsSetup extends FittyAgentState {
  final bool needsAiConfig;
  final bool needsConsent;

  const FittyAgentNeedsSetup({
    required this.needsAiConfig,
    required this.needsConsent,
  });

  @override
  List<Object?> get props => [needsAiConfig, needsConsent];
}

class FittyAgentReady extends FittyAgentState {
  final List<AgentChatBubble> bubbles;
  final bool sending;
  final String? errorMessage;

  const FittyAgentReady({
    required this.bubbles,
    this.sending = false,
    this.errorMessage,
  });

  FittyAgentReady copyWith({
    List<AgentChatBubble>? bubbles,
    bool? sending,
    String? errorMessage,
    bool clearError = false,
  }) => FittyAgentReady(
    bubbles: bubbles ?? this.bubbles,
    sending: sending ?? this.sending,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );

  @override
  List<Object?> get props => [bubbles, sending, errorMessage];
}

class AgentChatBubble extends Equatable {
  final bool fromUser;
  final String text;
  final bool isToolActivity;

  const AgentChatBubble({
    required this.fromUser,
    required this.text,
    this.isToolActivity = false,
  });

  @override
  List<Object?> get props => [fromUser, text, isToolActivity];
}
