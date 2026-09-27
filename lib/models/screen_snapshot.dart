import 'dart:convert';

import 'ui_node.dart';

class ScreenSnapshot {
  final String packageName;
  final Set<String> roles;
  final List<String> visibleTexts;
  final String stateHash;
  final DateTime capturedAt;

  const ScreenSnapshot({
    required this.packageName,
    required this.roles,
    required this.visibleTexts,
    required this.stateHash,
    required this.capturedAt,
  });

  factory ScreenSnapshot.fromTree(
    UiNode root, {
    required Iterable<String> Function(UiNode) rolesForNode,
  }) {
    final roles = <String>{};
    final text = <String>{};
    final structure = <String>[];
    for (final node in root.flatten()) {
      roles.addAll(rolesForNode(node));
      for (final value in [node.text, node.contentDescription]) {
        final normalized = _normalize(value);
        if (normalized.isNotEmpty) text.add(normalized);
      }
      structure.add(
        '${_normalize(node.className)}:${node.isClickable}:${node.isEditable}:${node.isScrollable}',
      );
    }
    final canonical = jsonEncode({
      'package': root.packageName ?? '',
      'roles': roles.toList()..sort(),
      'text': text.toList()..sort(),
      'structure': structure..sort(),
    });
    return ScreenSnapshot(
      packageName: root.packageName ?? '',
      roles: roles,
      visibleTexts: text.toList(),
      stateHash: _hash(canonical),
      capturedAt: DateTime.now(),
    );
  }

  static String _normalize(String? value) =>
      (value ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _hash(String value) {
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in utf8.encode(value)) {
      hash = (hash ^ codeUnit) * 0x100000001b3 & 0xffffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
