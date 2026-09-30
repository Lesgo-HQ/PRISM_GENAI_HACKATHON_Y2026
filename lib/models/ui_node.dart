class UiNode {
  final String? nodeId;
  final String? className;
  final String? text;
  final String? contentDescription;
  final String? hintText;
  final String? resourceId;
  final String? packageName;
  final Map<String, int> bounds; // {left, top, right, bottom}
  final bool isClickable;
  final bool isEditable;
  final bool isScrollable;
  final bool isCheckable;
  final bool isChecked;
  final bool isFocusable;
  final bool isFocused;
  final int inputType;
  final List<UiNode> children;

  UiNode({
    this.nodeId,
    this.className,
    this.text,
    this.contentDescription,
    this.hintText,
    this.resourceId,
    this.packageName,
    required this.bounds,
    required this.isClickable,
    required this.isEditable,
    required this.isScrollable,
    required this.isCheckable,
    required this.isChecked,
    required this.isFocusable,
    required this.isFocused,
    required this.inputType,
    required this.children,
  });

  factory UiNode.fromJson(Map<String, dynamic> json) {
    return UiNode(
      nodeId: json['nodeId'] as String?,
      className: json['className'] as String?,
      text: json['text'] as String?,
      contentDescription: json['contentDescription'] as String?,
      hintText: json['hintText'] as String?,
      resourceId: json['resourceId'] as String?,
      packageName: json['packageName'] as String?,
      bounds: json['bounds'] != null ? Map<String, int>.from(json['bounds'] as Map) : {'left': 0, 'top': 0, 'right': 0, 'bottom': 0},
      isClickable: json['isClickable'] as bool? ?? false,
      isEditable: json['isEditable'] as bool? ?? false,
      isScrollable: json['isScrollable'] as bool? ?? false,
      isCheckable: json['isCheckable'] as bool? ?? false,
      isChecked: json['isChecked'] as bool? ?? false,
      isFocusable: json['isFocusable'] as bool? ?? false,
      isFocused: json['isFocused'] as bool? ?? false,
      inputType: json['inputType'] as int? ?? 0,
      children:
          (json['children'] as List<dynamic>?)
              ?.map((e) => UiNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'className': className,
      'text': text,
      'contentDescription': contentDescription,
      'hintText': hintText,
      'resourceId': resourceId,
      'packageName': packageName,
      'bounds': bounds,
      'isClickable': isClickable,
      'isEditable': isEditable,
      'isScrollable': isScrollable,
      'isCheckable': isCheckable,
      'isChecked': isChecked,
      'isFocusable': isFocusable,
      'isFocused': isFocused,
      'inputType': inputType,
      'children': children.map((e) => e.toJson()).toList(),
    };
  }

  List<UiNode> flatten() {
    List<UiNode> result = [this];
    for (var child in children) {
      result.addAll(child.flatten());
    }
    return result;
  }
}
