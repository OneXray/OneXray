import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/advanced/local_api/settings.dart';
import 'package:onexray/service/connect/preparation.dart';

void main() {
  test('retries allocations that overlap Raw inbound ranges', () async {
    final candidates = [
      [11000, 12001],
      [14000, 13000],
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

    expect(attempts, 3);
    expect(ports, [11000, 13000]);
  });

  for (final apiPort in [LocalApiSettings.defaultPort, 19587]) {
    test('excludes HTTP API port $apiPort from both runtime ports', () async {
      final candidates = [
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

      expect(attempts, 2);
      expect(ports, [11000, 13000]);
    });
  }

  test(
    'keeps API and enabled LAN sharing ports out of runtime allocation',
    () async {
      final ports = await allocateRuntimePorts(
        const [],
        excludePorts: [LocalApiSettings.defaultPort, 11024],
        getFreePorts: (count, {excludePorts}) async {
          expect(count, 2);
          expect(excludePorts, [LocalApiSettings.defaultPort, 11024]);
          return [12001, 13000];
        },
      );
      expect(ports, [12001, 13000]);
    },
  );

  test(
    'preserves allocator failures without retrying invalid responses',
    () async {
      await expectLater(
        allocateRuntimePorts(
          const [],
          excludePorts: [LocalApiSettings.defaultPort],
          getFreePorts: (count, {excludePorts}) async {
            expect(count, 2);
            expect(excludePorts, [LocalApiSettings.defaultPort]);
            throw const FormatException('Invalid free ports response');
          },
        ),
        throwsFormatException,
      );
    },
  );

  test('stops after five unavailable runtime port groups', () async {
    var attempts = 0;
    await expectLater(
      allocateRuntimePorts(
        const [
          {'port': '11000-11010'},
        ],
        getFreePorts: (count, {excludePorts}) async {
          expect(count, 2);
          attempts++;
          return [11000, 13000];
        },
      ),
      throwsFormatException,
    );
    expect(attempts, 5);
  });
}
