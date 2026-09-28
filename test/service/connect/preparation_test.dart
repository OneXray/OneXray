import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/advanced/local_api/settings.dart';
import 'package:onexray/service/connect/preparation.dart';

void main() {
  test(
    'allocates two distinct valid ports outside Raw inbound ranges',
    () async {
      final candidates = [
        [11000],
        [11000, 11000],
        [11000, 65536],
        [11000, 12001],
        [11000, 13000],
      ];
      var attempts = 0;
      final ports = await allocateRuntimePorts(
        [
          {'port': '12000-12010,14000'},
        ],
        getFreePorts: (count, {excludePorts}) async {
          expect(count, 2);
          expect(excludePorts, isNull);
          return candidates[attempts++];
        },
      );

      expect(attempts, 5);
      expect(ports, [11000, 13000]);
    },
  );

  for (final apiPort in [LocalApiSettings.defaultPort, 19587]) {
    test('excludes HTTP API port $apiPort from both runtime ports', () async {
      final candidates = [
        [apiPort, 13000],
        [11000, apiPort],
        [11000, 12001],
        [11000, 13000],
      ];
      var attempts = 0;
      final ports = await allocateRuntimePorts(
        [
          {'port': '12000-12010'},
        ],
        excludePorts: [apiPort],
        getFreePorts: (count, {excludePorts}) async {
          expect(count, 2);
          expect(excludePorts, [apiPort]);
          return candidates[attempts++];
        },
      );

      expect(attempts, 4);
      expect(ports, [11000, 13000]);
    });
  }

  test('fails if every allocation contains the reserved API port', () async {
    var attempts = 0;
    await expectLater(
      allocateRuntimePorts(
        const [],
        excludePorts: [LocalApiSettings.defaultPort],
        getFreePorts: (count, {excludePorts}) async {
          expect(count, 2);
          expect(excludePorts, [LocalApiSettings.defaultPort]);
          attempts++;
          return [11000, LocalApiSettings.defaultPort];
        },
      ),
      throwsFormatException,
    );
    expect(attempts, 5);
  });

  test('stops after five unavailable runtime port groups', () async {
    var attempts = 0;
    await expectLater(
      allocateRuntimePorts(
        const [],
        getFreePorts: (count, {excludePorts}) async {
          expect(count, 2);
          attempts++;
          return [];
        },
      ),
      throwsFormatException,
    );
    expect(attempts, 5);
  });
}
