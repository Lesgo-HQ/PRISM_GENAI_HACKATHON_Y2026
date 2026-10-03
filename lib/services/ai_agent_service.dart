import 'dart:convert';
import 'llm_client.dart';

class AiAgentService {
  final LlmClient _llmClient = LlmClient.instance;

  Future<AgentPlan?> planTask(String task, String treeJson, {String? screenshotBase64}) async {
    final prompt = '''
You are an AI Agent that plans UI actions.
Task: "$task"
Accessibility Tree JSON:
$treeJson

Create a step-by-step plan to accomplish this task.
Return a structured JSON with the following schema:
{
  "taskSummary": "string",
  "requiresApp": boolean,
  "targetApp": "string or null",
  "steps": [
    {
      "action": "tap | type | scroll | swipe | back | home",
      "description": "string",
      "targetDescription": "string or null",
      "typedValue": "string or null",
      "coordinates": {"x": number, "y": number} or null
    }
  ]
}
''';

    final response = await _llmClient.generateContent(prompt);
    if (response != null) {
      try {
        final match = RegExp(r'```json\s*(.*?)\s*```', dotAll: true).firstMatch(response);
        final jsonStr = match != null ? match.group(1)! : response;
        final map = jsonDecode(jsonStr);

        final stepsList = (map['steps'] as List).map((s) => AgentStep(
          action: s['action'] ?? 'unknown',
          description: s['description'] ?? '',
          targetDescription: s['targetDescription'],
          typedValue: s['typedValue'],
          coordinates: s['coordinates'] != null ? Map<String, dynamic>.from(s['coordinates']) : null,
        )).toList();

        return AgentPlan(
          taskSummary: map['taskSummary'] ?? '',
          steps: stepsList,
          requiresApp: map['requiresApp'] ?? false,
          targetApp: map['targetApp'],
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<AgentAction?> nextAction(String task, String treeJson, List<AgentAction> history) async {
    final historyStr = history.map((a) => a.toJson()).toList().toString();
    final prompt = '''
You are an AI Agent operating a device.
Task: "$task"
Current Accessibility Tree JSON:
$treeJson
Action History:
$historyStr

Determine the very next action to take. Return structured JSON with:
{
  "action": "tap | type | scroll | swipe | back | home | finish",
  "reasoning": "string",
  "params": {} // any required parameters like targetDescription, text, etc.
}
''';

    final response = await _llmClient.generateContent(prompt);
    if (response != null) {
      try {
        final match = RegExp(r'```json\s*(.*?)\s*```', dotAll: true).firstMatch(response);
        final jsonStr = match != null ? match.group(1)! : response;
        final map = jsonDecode(jsonStr);
        return AgentAction(
          action: map['action'] ?? 'unknown',
          reasoning: map['reasoning'] ?? '',
          params: map['params'] != null ? Map<String, dynamic>.from(map['params']) : {},
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<double> scoreTaskMatch(String utterance, String flowIntent) async {
    final prompt = '''
Does the utterance "$utterance" match the flow intent "$flowIntent"?
Return a JSON object with a "score" field between 0.0 and 1.0 representing confidence.
''';

    final response = await _llmClient.generateContent(prompt);
    if (response != null) {
      try {
        final match = RegExp(r'```json\s*(.*?)\s*```', dotAll: true).firstMatch(response);
        final jsonStr = match != null ? match.group(1)! : response;
        final map = jsonDecode(jsonStr);
        return (map['score'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }
}

class AgentPlan {
  final String taskSummary;
  final List<AgentStep> steps;
  final bool requiresApp;
  final String? targetApp;

  AgentPlan({
    required this.taskSummary,
    required this.steps,
    required this.requiresApp,
    this.targetApp,
  });
}

class AgentStep {
  final String action;
  final String description;
  final String? targetDescription;
  final String? typedValue;
  final Map<String, dynamic>? coordinates;

  AgentStep({
    required this.action,
    required this.description,
    this.targetDescription,
    this.typedValue,
    this.coordinates,
  });
}

class AgentAction {
  final String action;
  final String reasoning;
  final Map<String, dynamic> params;

  AgentAction({
    required this.action,
    required this.reasoning,
    required this.params,
  });

  Map<String, dynamic> toJson() => {
    'action': action,
    'reasoning': reasoning,
    'params': params,
  };
}
