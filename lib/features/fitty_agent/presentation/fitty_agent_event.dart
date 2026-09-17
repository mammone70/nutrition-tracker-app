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
  final List<int>? imageBytes;
  final String? imageMediaType;

  const FittyAgentMessageSubmitted(
    this.text, {
    this.imageBytes,
    this.imageMediaType,
  });

  @override
  List<Object?> get props => [text, imageBytes, imageMediaType];
}

class FittyAgentCleared extends FittyAgentEvent {
  const FittyAgentCleared();
}
