import '../models/ui_node.dart';
import '../models/role_ontology.dart';

class ScreenAnalyzer {
  Map<String, dynamic> analyze(UiNode tree) {
    final nodes = tree.flatten();
    final roles = nodes.map((n) => RoleOntology.inferRole(n)).whereType<String>().toSet();
    
    String package = '';
    for (final node in nodes) {
      if (node.packageName?.isNotEmpty == true) {
        package = node.packageName!;
        break;
      }
    }
    
    final texts = nodes.map((n) => n.text).where((t) => t != null && t.isNotEmpty).cast<String>().toList();
    
    String screenType = 'unknown';
    if (roles.contains(RoleOntology.searchField)) {
      screenType = 'search';
    } else if (roles.contains(RoleOntology.productDetail)) screenType = 'product';
    else if (roles.contains(RoleOntology.cart)) screenType = 'cart';
    else if (roles.contains(RoleOntology.checkout)) screenType = 'checkout';
    else if (roles.contains(RoleOntology.payment) || roles.contains(RoleOntology.pay)) screenType = 'payment';
    else if (roles.contains(RoleOntology.login)) screenType = 'login';
    
    return {
      'roles': roles.toList(),
      'package': package,
      'texts': texts,
      'screenType': screenType,
    };
  }
}
