import 'ui_node.dart';

class ActionTraceEvent {
  final int timestampMs;
  final String action;
  final UiNode? node;
  final String? valueTyped;
  final String? packageName;

  ActionTraceEvent({
    required this.timestampMs,
    required this.action,
    this.node,
    this.valueTyped,
    this.packageName,
  });

  factory ActionTraceEvent.fromJson(Map<String, dynamic> json) {
    return ActionTraceEvent(
      timestampMs: json['timestampMs'] as int,
      action: json['action'] as String,
      node: json['node'] != null
          ? UiNode.fromJson(json['node'] as Map<String, dynamic>)
          : null,
      valueTyped: json['valueTyped'] as String?,
      packageName: json['packageName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestampMs': timestampMs,
      'action': action,
      if (node != null) 'node': node!.toJson(),
      if (valueTyped != null) 'valueTyped': valueTyped,
      if (packageName != null) 'packageName': packageName,
    };
  }
}
