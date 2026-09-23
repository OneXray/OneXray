import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('free-port exclusions are optional and round-trip as integers', () {
    expect(GetFreePortsRequest(2).toJson(), {'count': 2});
    final json = {
      'count': 2,
      'excludePorts': [18587, 9000],
    };
    expect(GetFreePortsRequest.fromJson(json).toJson(), json);
    expect(GetFreePortsRequest(0, excludePorts: []).toJson(), {
      'count': 0,
      'excludePorts': <int>[],
    });
  });

  test(
    'host forwards exclusions without changing the version or response',
    () async {
      const channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.onexray.BridgeHostApi.invoke',
        BridgeHostApi.pigeonChannelCodec,
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final payloads = <Map>[];
      messenger.setMockDecodedMessageHandler(channel, (request) async {
        final json = jsonDecode((request as List).single as String) as Map;
        expect(json['apiVersion'], 3);
        expect(json['method'], 'getFreePorts');
        payloads.add(json['payload'] as Map);
        return [
          jsonEncode({
            'success': true,
            'data': {
              'ports': [50001, 50002],
            },
            'error': '',
          }),
        ];
      });
      addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
      expect(await AppHostApi().getFreePorts(2), [50001, 50002]);
      expect(await AppHostApi().getFreePorts(2, excludePorts: [18587, 9000]), [
        50001,
        50002,
      ]);
      expect(payloads, [
        {'count': 2},
        {
          'count': 2,
          'excludePorts': [18587, 9000],
        },
      ]);
    },
    skip: !(Platform.isMacOS || Platform.isIOS || Platform.isAndroid),
  );
}
