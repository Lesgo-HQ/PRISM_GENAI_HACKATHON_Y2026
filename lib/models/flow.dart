import 'dart:convert';

class Slot {
  final String name;
  final String type;
  final dynamic defaultValue;
  final List<String>? values;
  final String? description;

  Slot({
    required this.name,
    this.type = 'string',
    this.defaultValue,
    this.values,
    this.description,
  });

  factory Slot.fromJson(Map<String, dynamic> json) {
    return Slot(
      name: json['name'] as String,
      type: json['type'] as String? ?? 'string',
      defaultValue: json['default'],
      values: (json['values'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'default': defaultValue,
      if (values != null) 'values': values,
      if (description != null) 'description': description,
    };
  }
}

class StepPrecondition {
  final List<String> requiredRoles;
  final List<String> forbiddenRoles;
  const StepPrecondition({
    this.requiredRoles = const [],
    this.forbiddenRoles = const [],
  });
  factory StepPrecondition.fromJson(Map<String, dynamic> j) => StepPrecondition(
    requiredRoles: (j['required_roles'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
    forbiddenRoles: (j['forbidden_roles'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'required_roles': requiredRoles,
    'forbidden_roles': forbiddenRoles,
  };
}

class StepPostcondition {
  final List<String> requiredRoles;
  const StepPostcondition({this.requiredRoles = const []});
  factory StepPostcondition.fromJson(Map<String, dynamic> j) =>
      StepPostcondition(
        requiredRoles: (j['required_roles'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );
  Map<String, dynamic> toJson() => {'required_roles': requiredRoles};
}

class FlowStep {
  final int id;
  final String action;
  final String targetRole;
  final String? targetNodeText;
  final String? targetNodeContentDescription;
  final String? targetNodeResourceId;
  final int? scrollDeltaX;
  final int? scrollDeltaY;
  final String? valueSlot;
  final String? valueLiteral;
  final StepPrecondition? precondition;
  final StepPostcondition? postcondition;
  final List<String> recovery;

  FlowStep({
    required this.id,
    required this.action,
    required this.targetRole,
    this.targetNodeText,
    this.targetNodeContentDescription,
    this.targetNodeResourceId,
    this.scrollDeltaX,
    this.scrollDeltaY,
    this.valueSlot,
    this.valueLiteral,
    this.precondition,
    this.postcondition,
    this.recovery = const [],
  });

  factory FlowStep.fromJson(Map<String, dynamic> json) {
    return FlowStep(
      id: json['id'] as int,
      action: json['action'] as String,
      targetRole: json['target_role'] as String,
      targetNodeText: json['target_node_text'] as String?,
      targetNodeContentDescription:
          json['target_node_content_description'] as String?,
      targetNodeResourceId: json['target_node_resource_id'] as String?,
      scrollDeltaX: json['scroll_delta_x'] as int?,
      scrollDeltaY: json['scroll_delta_y'] as int?,
      valueSlot: json['value_slot'] as String?,
      valueLiteral: json['value_literal'] as String?,
      precondition: json['precondition'] != null
          ? StepPrecondition.fromJson(
              json['precondition'] as Map<String, dynamic>,
            )
          : null,
      postcondition: json['postcondition'] != null
          ? StepPostcondition.fromJson(
              json['postcondition'] as Map<String, dynamic>,
            )
          : null,
      recovery: (json['recovery'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'target_role': targetRole,
      if (targetNodeText != null) 'target_node_text': targetNodeText,
      if (targetNodeContentDescription != null)
        'target_node_content_description': targetNodeContentDescription,
      if (targetNodeResourceId != null)
        'target_node_resource_id': targetNodeResourceId,
      if (scrollDeltaX != null) 'scroll_delta_x': scrollDeltaX,
      if (scrollDeltaY != null) 'scroll_delta_y': scrollDeltaY,
      if (valueSlot != null) 'value_slot': valueSlot,
      if (valueLiteral != null) 'value_literal': valueLiteral,
      if (precondition != null) 'precondition': precondition!.toJson(),
      if (postcondition != null) 'postcondition': postcondition!.toJson(),
      if (recovery.isNotEmpty) 'recovery': recovery,
    };
  }

  bool validatePrecondition(Set<String> screenRoles) {
    if (precondition == null) return true;
    final requiredRoles = precondition!.requiredRoles.where(
      (role) => !role.startsWith('GENERIC_'),
    );
    if (requiredRoles.any((role) => !screenRoles.contains(role))) {
      return false;
    }
    if (precondition!.forbiddenRoles.any(screenRoles.contains)) return false;
    return true;
  }

  bool validatePostcondition(Set<String> screenRoles) {
    if (postcondition == null) return true;
    return postcondition!.requiredRoles.every(screenRoles.contains);
  }
}

class Flow {
  final String flowId;
  final String appPackage;
  final String triggerIntent;
  final List<String> exampleUtterances;
  final List<Slot> slots;
  final List<FlowStep> steps;

  Flow({
    required this.flowId,
    required this.appPackage,
    required this.triggerIntent,
    required this.exampleUtterances,
    required this.slots,
    required this.steps,
  });

  factory Flow.fromJson(Map<String, dynamic> json) {
    return Flow(
      flowId: json['flow_id'] as String,
      appPackage: json['app_package'] as String,
      triggerIntent: json['trigger_intent'] as String,
      exampleUtterances: (json['example_utterances'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      slots: (json['slots'] as List<dynamic>)
          .map((e) => Slot.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List<dynamic>)
          .map((e) => FlowStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flow_id': flowId,
      'app_package': appPackage,
      'trigger_intent': triggerIntent,
      'example_utterances': exampleUtterances,
      'slots': slots.map((e) => e.toJson()).toList(),
      'steps': steps.map((e) => e.toJson()).toList(),
    };
  }

  factory Flow.fromMap(Map<String, dynamic> map) {
    return Flow(
      flowId: map['flow_id'] as String,
      appPackage: map['app_package'] as String,
      triggerIntent: map['trigger_intent'] as String,
      exampleUtterances: (jsonDecode(
        map['example_utterances'] as String,
      ) as List<dynamic>).map((e) => e as String).toList(),
      slots: (jsonDecode(map['slots'] as String) as List<dynamic>)
          .map((e) => Slot.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (jsonDecode(map['steps'] as String) as List<dynamic>)
          .map((e) => FlowStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'flow_id': flowId,
      'app_package': appPackage,
      'trigger_intent': triggerIntent,
      'example_utterances': jsonEncode(exampleUtterances),
      'slots': jsonEncode(slots.map((e) => e.toJson()).toList()),
      'steps': jsonEncode(steps.map((e) => e.toJson()).toList()),
    };
  }
}
