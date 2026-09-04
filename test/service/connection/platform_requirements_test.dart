import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/connection/platform_requirements.dart';
import 'package:onexray/service/connection/settings.dart';

void main() {
  test('non-desktop platforms do not read outbound interfaces', () async {
    final requirements = ConnectionPlatformRequirements(
      platform: ConnectionPlatform.android,
      interfaceNames: () => throw StateError('must not query interfaces'),
    );

    await requirements.ensureOutboundInterface('');
  });

  test('Windows requires an outbound interface before starting', () async {
    final requirements = ConnectionPlatformRequirements(
      platform: ConnectionPlatform.windows,
      interfaceNames: () async => {'Ethernet'},
    );

    await expectLater(
      requirements.ensureOutboundInterface(''),
      throwsA(
        isA<ConnectionPlatformRequirementException>().having(
          (error) => error.failure,
          'failure',
          ConnectionPlatformRequirementFailure.outboundInterfaceRequired,
        ),
      ),
    );
  });

  test('Linux rejects a saved interface that no longer exists', () async {
    final requirements = ConnectionPlatformRequirements(
      platform: ConnectionPlatform.linux,
      interfaceNames: () async => {'eth0'},
    );

    await expectLater(
      requirements.ensureOutboundInterface('wlan0'),
      throwsA(
        isA<ConnectionPlatformRequirementException>().having(
          (error) => error.failure,
          'failure',
          ConnectionPlatformRequirementFailure.outboundInterfaceUnavailable,
        ),
      ),
    );
  });

  test('saved interface is accepted when it still exists', () async {
    final requirements = ConnectionPlatformRequirements(
      platform: ConnectionPlatform.windows,
      interfaceNames: () async => {'Ethernet', 'Wi-Fi'},
    );

    await requirements.ensureOutboundInterface('Wi-Fi');
  });
}
