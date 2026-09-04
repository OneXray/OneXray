import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/connection/preparation.dart';

void main() {
  test(
    'allocates three distinct valid ports outside Raw inbound ranges',
    () async {
      final candidates = [
        [11000, 11001],
        [11000, 11001, 11001],
        [11000, 11001, 65536],
        [11000, 11001, 12001],
        [11000, 11001, 13000],
      ];
      var attempts = 0;
      final ports = await allocateRuntimePorts(
        [
          {'port': '12000-12010,14000'},
        ],
        getFreePorts: (count) async {
          expect(count, 3);
          return candidates[attempts++];
        },
      );

      expect(attempts, 5);
      expect(ports, [11000, 11001, 13000]);
    },
  );

  test('stops after five unavailable runtime port groups', () async {
    var attempts = 0;
    await expectLater(
      allocateRuntimePorts(
        const [],
        getFreePorts: (count) async {
          expect(count, 3);
          attempts++;
          return [];
        },
      ),
      throwsFormatException,
    );
    expect(attempts, 5);
  });
}
