import 'dart:io';

final _packageDirectivePattern = RegExp(
  r'''^[ \t]*(?:import|export)\s+['"]package:onexray/([^/'"]+)/''',
  multiLine: true,
);

Iterable<String> packageDirectiveLayers(String source) sync* {
  for (final match in _packageDirectivePattern.allMatches(source)) {
    final layer = match.group(1);
    if (layer != null) {
      yield layer;
    }
  }
}

Future<void> main() async {
  final violations = <String>[];
  await _checkLayer(
    directory: Directory('lib/core'),
    forbiddenLayers: const {'service', 'pages'},
    violations: violations,
  );
  await _checkLayer(
    directory: Directory('lib/service'),
    forbiddenLayers: const {'pages'},
    violations: violations,
  );

  if (violations.isEmpty) {
    stdout.writeln('Layer dependencies are valid.');
    return;
  }
  violations.sort();
  stderr.writeln('Invalid reverse layer dependencies:');
  for (final violation in violations) {
    stderr.writeln('  $violation');
  }
  exitCode = 1;
}

Future<void> _checkLayer({
  required Directory directory,
  required Set<String> forbiddenLayers,
  required List<String> violations,
}) async {
  await for (final entity in directory.list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final source = await entity.readAsString();
    for (final layer in packageDirectiveLayers(source)) {
      if (forbiddenLayers.contains(layer)) {
        violations.add('${entity.path} depends on $layer');
      }
    }
  }
}
