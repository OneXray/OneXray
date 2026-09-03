import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/connection/preparation.dart';

void main() {
  test(
    'allocates four distinct valid ports outside Raw inbound ranges',
    () async {
      final candidates = [
        [11000, 11001, 11002],
        [11000, 11001, 11002, 11002],
        [11000, 11001, 11002, 65536],
        [11000, 11001, 11002, 12001],
        [11000, 11001, 11002, 13000],
      ];
      var attempts = 0;
      final ports = await allocateRuntimePorts(
        [
          {'port': '12000-12010,14000'},
        ],
        getFreePorts: (count) async {
          expect(count, 4);
          return candidates[attempts++];
        },
      );

      expect(attempts, 5);
      expect(ports, [11000, 11001, 11002, 13000]);
    },
  );

  test('stops after five unavailable runtime port groups', () async {
    var attempts = 0;
    await expectLater(
      allocateRuntimePorts(
        const [],
        getFreePorts: (count) async {
          expect(count, 4);
          attempts++;
          return [];
        },
      ),
      throwsFormatException,
    );
    expect(attempts, 5);
  });
}
