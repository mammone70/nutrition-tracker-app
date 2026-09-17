import 'package:equatable/equatable.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';

abstract class FittyAgentEvent extends Equatable {
  const FittyAgentEvent();

  @override
  List<Object?> get props => [];
}

class FittyAgentStarted extends FittyAgentEvent {
  const FittyAgentStarted();
}

class FittyAgentConsentAccepted extends FittyAgentEvent {
  const FittyAgentConsentAccepted();
}

class FittyAgentMessageSubmitted extends FittyAgentEvent {
  final String text;
  final List<AgentAttachedImage> images;

  const FittyAgentMessageSubmitted(this.text, {this.images = const []});

  @override
  List<Object?> get props => [text, images];
}

class FittyAgentCleared extends FittyAgentEvent {
  const FittyAgentCleared();
}
