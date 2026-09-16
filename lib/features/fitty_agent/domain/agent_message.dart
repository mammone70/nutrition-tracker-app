/// One turn in a Fitty Agent conversation, independent of provider wire format.
sealed class AgentMessage {
  const AgentMessage();
}

final class AgentUserMessage extends AgentMessage {
  final String text;

  const AgentUserMessage(this.text);
}

final class AgentAssistantMessage extends AgentMessage {
  final String? text;
  final List<AgentToolCall> toolCalls;

  const AgentAssistantMessage({this.text, this.toolCalls = const []});
}

final class AgentToolResultMessage extends AgentMessage {
  final String toolCallId;
  final String name;
  final String content;

  const AgentToolResultMessage({
    required this.toolCallId,
    required this.name,
    required this.content,
  });
}

class AgentToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const AgentToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}
