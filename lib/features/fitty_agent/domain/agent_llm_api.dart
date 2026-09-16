import 'package:opennutritracker/features/fitty_agent/domain/agent_message.dart';
import 'package:opennutritracker/features/fitty_agent/domain/agent_tool.dart';

/// Multi-turn tool loop against the same LLM credentials as AI meal assist.
abstract interface class AgentLlmApi {
  /// Runs until the model returns a final text reply or [maxRounds] is hit.
  Future<AgentTurnResult> runTurn({
    required String system,
    required List<AgentMessage> history,
    required List<AgentToolDefinition> tools,
    required Future<String> Function(AgentToolCall call) executeTool,
    int maxRounds = 24,
  });
}

class AgentTurnResult {
  final String reply;
  final List<AgentMessage> newMessages;

  const AgentTurnResult({required this.reply, required this.newMessages});
}
