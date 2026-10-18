import 'dart:convert';

/// A semantic judgment is separate from routing confidence and execution consent.
enum SkillVerdict { supported, review, ambiguous, unsupported, notAction }

class SkillAssessment {
  final SkillVerdict verdict;
  final String reason;
  const SkillAssessment(this.verdict, this.reason);

  factory SkillAssessment.parse(String raw) {
    final value = jsonDecode(raw);
    const values = {
      'supported': SkillVerdict.supported,
      'review': SkillVerdict.review,
      'ambiguous': SkillVerdict.ambiguous,
      'unsupported': SkillVerdict.unsupported,
      'not_action': SkillVerdict.notAction,
    };
    if (value is! Map ||
        !values.containsKey(value['verdict']) ||
        value['reason'] is! String ||
        (value['reason'] as String).trim().isEmpty ||
        (value['reason'] as String).length > 600) {
      throw const FormatException('Invalid skill assessment');
    }
    return SkillAssessment(values[value['verdict']]!, value['reason']);
  }

  static const schema = {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'verdict': {
        'type': 'string',
        'enum': [
          'supported',
          'review',
          'ambiguous',
          'unsupported',
          'not_action',
        ],
      },
      'reason': {'type': 'string', 'minLength': 1, 'maxLength': 600},
    },
    'required': ['verdict', 'reason'],
  };
}
