import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Flutter UI uses Lucide icons instead of Material or Cupertino icons',
    () {
      final legacyIconPattern = RegExp(r'\b(?:Icons|CupertinoIcons)\.');
      final violations = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final lines = entity.readAsLinesSync();
        for (var index = 0; index < lines.length; index++) {
          if (legacyIconPattern.hasMatch(lines[index])) {
            violations.add(
              '${entity.path}:${index + 1}: ${lines[index].trim()}',
            );
          }
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}
