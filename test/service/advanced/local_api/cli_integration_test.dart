import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/advanced/local_api/configuration.dart';
import 'package:onexray/service/advanced/local_api/server.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Go CLI uses real HTTP and App parsing/compilation contracts',
    () async {
      final repository = Directory.current.absolute.path;
      final evidenceRoot = Directory(
        p.join(p.dirname(repository), 'references', 'client-improvements'),
      );
      await evidenceRoot.create(recursive: true);
      final fixture = await evidenceRoot.createTemp('cli-integration-');
      var kernelCalls = 0;
      final configuration = LocalApiConfiguration(
        withResources: (action) => action(),
        testXray: (text) async {
          kernelCalls++;
          final projected = jsonDecode(text) as Map<String, dynamic>;
          expect(projected['outbounds'], isNotEmpty);
          expect(projected['outbounds'].single['protocol'], 'freedom');
          expect(projected.containsKey('inbounds'), false);
          expect(projected['log']['error'], 'none');
          return '';
        },
      );
      final server = LocalApiServer(
        token: () => 'dart-cli-integration-012345678901234567890123456789',
        available: () => true,
        info: () async => {
          'appVersion': 'integration-test',
          'coreVersion': 'stub-no-native-core',
          'platform': 'macos',
          'supportedKinds': ['outbound', 'routing', 'advanced-routing', 'raw'],
        },
        validate: configuration.validate,
        compile: configuration.compile,
      );
      addTearDown(() async {
        await server.close();
        await server.drained;
        await fixture.delete(recursive: true);
      });
      server.attach(await LocalApiServer.bind(0));

      // Runs production Go App.Run with isolated test credentials, not the
      // packaged terminal main. No HOME change or actual App credential access.
      final result = await Process.run(
        'go',
        [
          'test',
          './internal/cli',
          '-run',
          r'^TestDartAPIIntegration$',
          '-count=1',
          '-timeout=30s',
          '-v',
        ],
        workingDirectory: p.join(repository, 'cli'),
        environment: {
          'ONEXRAY_DART_API_ENDPOINT': 'http://127.0.0.1:${server.port}',
          'ONEXRAY_DART_TEST_DIRECTORY': fixture.path,
        },
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('--- PASS: TestDartAPIIntegration'));
      // info/auth and compile never invoke native validation. The invalid
      // sourceIP document fails at the same App parser used by the editor.
      expect(kernelCalls, 1);
      final preview = jsonDecode(
        await File(p.join(fixture.path, 'preview.json')).readAsString(),
      ) as Map<String, dynamic>;
      expect(preview['inbounds'].single['protocol'], 'tun');
      expect(preview['outbounds'].single['protocol'], 'freedom');
      expect(preview['metrics']['listen'], startsWith('127.0.0.1:'));
    },
    skip: Platform.environment['ONEXRAY_GO_INTEGRATION'] == '1' ? false : 'Set ONEXRAY_GO_INTEGRATION=1 to run the local Go/Dart transport test.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
