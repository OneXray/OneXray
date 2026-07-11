import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_layer_dependencies.dart';

void main() {
  test('finds package imports and exports with leading whitespace', () {
    const source = '''
import 'package:onexray/core/model/example.dart';
  import "package:onexray/service/example.dart";
\texport 'package:onexray/pages/example.dart';
export 'package:other/package.dart';
''';

    expect(packageDirectiveLayers(source), ['core', 'service', 'pages']);
  });
}
