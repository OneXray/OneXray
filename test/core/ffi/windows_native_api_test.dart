import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/ffi/windows/native_api.dart';

void main() {
  test('queries the canonical Windows VPN profile state', () async {
    final digest = List.filled(64, 'a').join();
    String? requestJson;
    final api = WindowsNativeApi.forTest((request) async {
      requestJson = request;
      return jsonEncode({
        'success': true,
        'data': {
          'status': 'connected',
          'snapshotToken': 'vcore-session-v2:$digest',
        },
        'error': '',
      });
    });

    final state = await api.getVpnStatus();

    expect(state.status, WindowsVpnStatus.connected);
    expect(state.snapshotToken, 'vcore-session-v2:$digest');
    expect(jsonDecode(requestJson!), {
      'bridgeVersion': 3,
      'method': 'getVpnStatus',
      'payload': <String, Object?>{},
    });
  });

  test(
    'passes network settings, policy, and managed processes in start',
    () async {
      String? requestJson;
      final digest = List.filled(64, 'b').join();
      final api = WindowsNativeApi.forTest((request) async {
        requestJson = request;
        return jsonEncode({
          'success': true,
          'data': {
            'status': 'connected',
            'snapshotToken': 'vcore-session-v2:$digest',
          },
          'error': '',
        });
      });

      await api.startVpn(
        'ipv6: true\ntun:\n  enable: true\n',
        const WindowsVpnNetworkSettings(
          ipv4Address: '192.168.8.1',
          ipv6Address: 'fd00:8::2',
          dnsIpv4Address: '223.5.5.5',
          dnsIpv6Address: '2400:3200::1',
        ),
        policy: const WindowsVpnPolicy(
          alwaysOn: true,
          allowLocalNetwork: false,
          excludedCidrs: ['192.0.2.0/24', '2001:db8::/64'],
        ),
        sessionBackend: const WindowsSessionBackend(
          processes: [
            WindowsManagedProcess(
              executableRelativePath: 'OneXrayCore.exe',
              arguments: [
                'run',
                '-dns',
                '8.8.8.8:53',
                '-interface',
                'Ethernet',
                '-config',
                r'C:\config.json',
              ],
            ),
          ],
        ),
      );

      expect(jsonDecode(requestJson!), {
        'bridgeVersion': 3,
        'method': 'startVpn',
        'payload': {
          'configYaml': 'ipv6: true\ntun:\n  enable: true\n',
          'networkSettings': {
            'ipv4Address': '192.168.8.1',
            'ipv6Address': 'fd00:8::2',
            'dnsIpv4Address': '223.5.5.5',
            'dnsIpv6Address': '2400:3200::1',
          },
          'policy': {
            'alwaysOn': true,
            'allowLocalNetwork': false,
            'excludedCidrs': ['192.0.2.0/24', '2001:db8::/64'],
          },
          'sessionBackend': {
            'processes': [
              {
                'executableRelativePath': 'OneXrayCore.exe',
                'arguments': [
                  'run',
                  '-dns',
                  '8.8.8.8:53',
                  '-interface',
                  'Ethernet',
                  '-config',
                  r'C:\config.json',
                ],
              },
            ],
          },
        },
      });
    },
  );

  test(
    'serializes all policy fields, including false and an empty CIDR list',
    () {
      final policyJson = const WindowsVpnPolicy(
        alwaysOn: false,
        allowLocalNetwork: true,
        excludedCidrs: [],
      ).toJson();

      expect(policyJson, {
        'alwaysOn': false,
        'allowLocalNetwork': true,
        'excludedCidrs': <String>[],
      });
      expect(WindowsVpnPolicy.fromJson(policyJson).toJson(), policyJson);
    },
  );

  test('requires every policy field and rejects unknown policy fields', () {
    final policyJson = const WindowsVpnPolicy(
      alwaysOn: false,
      allowLocalNetwork: true,
      excludedCidrs: [],
    ).toJson();

    for (final key in policyJson.keys) {
      expect(
        () => WindowsVpnPolicy.fromJson({...policyJson}..remove(key)),
        throwsA(isA<MissingRequiredKeysException>()),
      );
    }
    expect(
      () => WindowsVpnPolicy.fromJson({...policyJson, 'unexpected': true}),
      throwsA(isA<UnrecognizedKeysException>()),
    );
  });

  test('requires a policy in the start payload', () {
    expect(
      () => WindowsStartVpnPayload.fromJson({
        'configYaml': 'tun:\n  enable: true\n',
        'networkSettings': {
          'ipv4Address': '192.168.8.1',
          'ipv6Address': 'fd00:8::2',
          'dnsIpv4Address': '223.5.5.5',
          'dnsIpv6Address': '2400:3200::1',
        },
      }),
      throwsA(isA<MissingRequiredKeysException>()),
    );
  });

  test('rejects a successful response with a noncanonical token', () async {
    final api = WindowsNativeApi.forTest((_) async {
      return jsonEncode({
        'success': true,
        'data': {'status': 'connected', 'snapshotToken': '../config.yaml'},
        'error': '',
      });
    });

    await expectLater(api.getVpnStatus(), throwsA(isA<FormatException>()));
  });

  test('rejects malformed native response models', () async {
    final api = WindowsNativeApi.forTest((_) async {
      return jsonEncode({
        'success': true,
        'data': {'state': 'disabled'},
        'error': '',
        'unexpected': true,
      });
    });

    await expectLater(
      api.getStartupTaskStatus(),
      throwsA(isA<FormatException>()),
    );
  });

  test('surfaces bounded native failures', () async {
    final api = WindowsNativeApi.forTest((_) async {
      return jsonEncode({
        'success': false,
        'data': null,
        'error': 'Windows VPN profile is busy',
      });
    });

    await expectLater(
      api.stopVpn(),
      throwsA(
        isA<WindowsNativeException>().having(
          (error) => error.message,
          'message',
          'Windows VPN profile is busy',
        ),
      ),
    );
  });

  test('serializes bridge calls', () async {
    var active = 0;
    var maxActive = 0;
    final api = WindowsNativeApi.forTest((request) async {
      active++;
      if (active > maxActive) maxActive = active;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      active--;
      return jsonEncode({
        'success': true,
        'data': {'state': 'disabled'},
        'error': '',
      });
    });

    await Future.wait([api.getStartupTaskStatus(), api.getStartupTaskStatus()]);

    expect(maxActive, 1);
  });
}
