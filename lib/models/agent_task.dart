import 'dart:convert';

import 'ui_node.dart';

/// A target index is valid only for the observation that produced it.
class AgentObservation {
  final String package;
  final List<UiNode> nodes;
  AgentObservation(UiNode tree)
    : package = tree.packageName ?? '',
      nodes = tree
          .flatten()
          .where(
            (n) =>
                n.packageName != 'com.lesgo.saar' &&
                (n.isClickable ||
                    n.isEditable ||
                    n.isScrollable ||
                    (n.text?.isNotEmpty ?? false)),
          )
          .take(100)
          .toList();
  Map<String, dynamic> toJson() => {
    'package': package,
    'elements': [
      for (var i = 0; i < nodes.length; i++)
        {
          'id': i,
          'text': nodes[i].text,
          if (nodes[i].isClickable && (nodes[i].text?.isEmpty ?? true))
            'child_text': nodes[i]
                .flatten()
                .skip(1)
                .map((n) => n.text ?? '')
                .where((text) => text.isNotEmpty)
                .take(6)
                .join(' · '),
          'description': nodes[i].contentDescription,
          'resource': nodes[i].resourceId,
          'clickable': nodes[i].isClickable,
          'editable': nodes[i].isEditable,
          'scrollable': nodes[i].isScrollable,
          'focused': nodes[i].isFocused,
          'checkable': nodes[i].isCheckable,
          'checked': nodes[i].isChecked,
          'bounds': nodes[i].bounds,
        },
    ],
  };
  String get fingerprint => jsonEncode(toJson());
  Map<String, dynamic> toModelJson() {
    final data = toJson();
    // Keep full geometry locally for stale-target checks, not in model prompts.
    for (final element in data['elements'] as List) {
      if (element.remove('checkable') == true) {
        element['selection_state'] = element['checked'] == true ? 'on' : 'off';
      }
      element.remove('checked');
      (element as Map).removeWhere(
        (key, value) =>
            key == 'bounds' ||
            key == 'focused' ||
            value == null ||
            value == '' ||
            value == false,
      );
    }
    return data;
  }

  String get stateKey {
    var hash = 2166136261;
    for (final unit in fingerprint.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }
}

class AgentAction {
  final String action;
  final int? target;
  final String text;
  final String reason;
  final String expectation;
  const AgentAction(
    this.action,
    this.target,
    this.text,
    this.reason,
    this.expectation,
  );
  factory AgentAction.parse(String raw, AgentObservation observation) {
    final j = jsonDecode(raw);
    if (j is! Map ||
        ![
          'tap',
          'type',
          'scroll',
          'back',
          'ask',
          'finish',
        ].contains(j['action']) ||
        j['text'] is! String ||
        j['reason'] is! String ||
        j['expectation'] is! String) {
      throw const FormatException('Invalid agent action');
    }
    final target = j['target'];
    final action = j['action'] as String;
    if (['tap', 'type', 'scroll'].contains(action)) {
      if (target is! int || target < 0 || target >= observation.nodes.length) {
        throw const FormatException('Target is not in the current screen');
      }
      final node = observation.nodes[target];
      if ((action == 'type' && !node.isEditable) ||
          (action == 'scroll' && !node.isScrollable) ||
          (action == 'tap' && !node.isClickable && !node.isEditable)) {
        throw const FormatException('Target does not support this action');
      }
    } else if (target != null) {
      throw const FormatException(
        'Non-targeted action must have a null target',
      );
    }
    if (action == 'scroll' && !['up', 'down'].contains(j['text'])) {
      throw const FormatException('Invalid scroll direction');
    }
    if (['type', 'ask'].contains(action) &&
        (j['text'] as String).trim().isEmpty) {
      throw const FormatException('Action requires text');
    }
    if ((j['text'] as String).length > 2000) {
      throw const FormatException('Text too long');
    }
    return AgentAction(
      action,
      target as int?,
      j['text'],
      j['reason'],
      j['expectation'],
    );
  }
  Map<String, dynamic> toJson() => {
    'action': action,
    'target': target,
    'text': text,
    'reason': reason,
    'expectation': expectation,
  };
}

class AgentTask {
  final String id;
  String goal;
  final String package;
  String status;
  int turns;
  bool actionPending;
  final List<Map<String, dynamic>> history;
  AgentTask({
    required this.id,
    required this.goal,
    required this.package,
    this.status = 'running',
    this.turns = 0,
    this.actionPending = false,
    List<Map<String, dynamic>>? history,
  }) : history = history ?? [];
  Map<String, dynamic> toJson() => {
    'id': id,
    'goal': goal,
    'package': package,
    'status': status,
    'turns': turns,
    'actionPending': actionPending,
    'history': history,
  };
  factory AgentTask.fromJson(Map<String, dynamic> j) => AgentTask(
    id: j['id'],
    goal: j['goal'],
    package: j['package'],
    status: 'paused',
    turns: j['turns'],
    actionPending: j['actionPending'],
    history: (j['history'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
  );
}
