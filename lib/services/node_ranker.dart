import '../models/role_ontology.dart';
import '../models/ui_node.dart';

class NodeMatch {
  final UiNode node;
  final double score;
  final bool isAmbiguous;

  const NodeMatch(this.node, this.score, {this.isAmbiguous = false});
}

class NodeRanker {
  static const double executeThreshold = 0.60;
  static const double clarifyThreshold = 0.45;

  NodeMatch? best(Iterable<UiNode> nodes, String targetRole, String actionType) {
    final ranked = nodes.map((node) => NodeMatch(node, _score(node, targetRole, actionType))).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
      
    if (ranked.isEmpty) return null;
    
    final bestMatch = ranked[0];
    if (bestMatch.score < clarifyThreshold) return null; // Below clarify threshold, don't try
    
    bool isAmbiguous = false;
    if (ranked.length > 1) {
      final secondBest = ranked[1];
      if (bestMatch.score >= clarifyThreshold && bestMatch.score - secondBest.score <= 0.05) {
        isAmbiguous = true;
      }
    }
    
    if (bestMatch.score < executeThreshold || isAmbiguous) {
      return NodeMatch(bestMatch.node, bestMatch.score, isAmbiguous: true);
    }
    
    return bestMatch;
  }

  double _score(UiNode node, String targetRole, String actionType) {
    final roleScore = RoleOntology.matchScore(node, targetRole);
    
    final text = '${node.text ?? ''}'.toLowerCase();
    final terms = targetRole.toLowerCase().split('_');
    final textScore = terms.isNotEmpty ? terms.where(text.contains).length / terms.length : 0.0;
    
    final contentDesc = '${node.contentDescription ?? ''}'.toLowerCase();
    final contentDescScore = terms.isNotEmpty ? terms.where(contentDesc.contains).length / terms.length : 0.0;
    
    double classScore = 0.0;
    if (actionType == 'type' || actionType == 'set_quantity') {
      if (node.isEditable) classScore = 1.0;
      else if (node.className?.contains('EditText') == true) classScore = 1.0;
    } else {
      if (node.isClickable) classScore = 1.0;
      else if (node.className?.contains('Button') == true) classScore = 1.0;
    }
    
    final clickEditScore = (node.isClickable || node.isEditable) ? 1.0 : 0.0;
    
    // Structural context (simplified placeholder)
    final structScore = node.children.isNotEmpty ? 0.3 : 0.0;

    // Role compatibility - weight 0.40
    // Text similarity - weight 0.15
    // Content description similarity - weight 0.10
    // Class compatibility - weight 0.15
    // Clickability/editability match - weight 0.10
    // Structural context - weight 0.05

    final score = (roleScore * 0.40) + 
                  (textScore * 0.15) + 
                  (contentDescScore * 0.10) + 
                  (classScore * 0.15) + 
                  (clickEditScore * 0.10) + 
                  (structScore * 0.05);
                  
    return score.clamp(0.0, 1.0).toDouble();
  }
}
