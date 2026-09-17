/// One turn in a Fitty Agent conversation, independent of provider wire format.
sealed class AgentMessage {
  const AgentMessage();
}

/// An image attached to a user turn (encoded meal photo bytes + MIME type).
final class AgentAttachedImage {
  final List<int> bytes;
  final String mediaType;

  const AgentAttachedImage({required this.bytes, required this.mediaType});

  bool get isValid => bytes.isNotEmpty && mediaType.isNotEmpty;
}

final class AgentUserMessage extends AgentMessage {
  final String text;

  /// Encoded meal photos for this turn (e.g. from [MealPhotoEncoder]).
  final List<AgentAttachedImage> images;

  const AgentUserMessage(this.text, {this.images = const []});

  bool get hasImages => images.any((image) => image.isValid);

  /// Valid images only, preserving order.
  List<AgentAttachedImage> get validImages =>
      images.where((image) => image.isValid).toList(growable: false);
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
