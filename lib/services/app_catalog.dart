import '../models/flow.dart';

/// App identities come from Android and saved workflows, not a brand allowlist.
class AppCatalog {
  final Map<String, String> names;
  AppCatalog({
    Map<String, String> installed = const {},
    List<Flow> flows = const [],
  }) : names = {
         for (final flow in flows) flow.appPackage: flow.appPackage,
         ...installed,
       };

  String label(String package) => names[package] ?? package;

  Set<String> explicitDestinations(String request) {
    final matches = <String>{};
    for (final entry in names.entries) {
      final aliases = <String>{
        entry.key,
        entry.value,
        if (entry.value == entry.key)
          ...entry.key
              .split('.')
              .where(
                (part) =>
                    part.length > 2 &&
                    !{
                      'com',
                      'org',
                      'net',
                      'android',
                      'application',
                      'app',
                      'apps',
                    }.contains(part),
              ),
      };
      for (final alias in aliases) {
        if (alias.trim().isEmpty) continue;
        // This only guards explicit app references. The model resolves other
        // wording/languages and whether a mention describes an app or an item.
        final pattern = RegExp(
          '(?:^|\\s)(?:on|in|from|using|via|with)\\s+(?:the\\s+)?${RegExp.escape(alias)}(?=\\s|[.!?,]|\$)',
          caseSensitive: false,
        );
        if (pattern.hasMatch(request)) matches.add(entry.key);
      }
    }
    return matches;
  }
}
