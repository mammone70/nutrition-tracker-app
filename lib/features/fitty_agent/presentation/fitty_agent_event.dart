import 'package:equatable/equatable.dart';

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

  const FittyAgentMessageSubmitted(this.text);

  @override
  List<Object?> get props => [text];
}

class FittyAgentCleared extends FittyAgentEvent {
  const FittyAgentCleared();
}
