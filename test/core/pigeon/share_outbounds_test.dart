import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/shared/share/xray_share_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.onexray.BridgeHostApi.invoke',
    BridgeHostApi.pigeonChannelCodec,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'share conversion reads only outbounds and uses libXray acceptance',
    () async {
      final valid = {'tag': 'Valid', 'protocol': 'freedom'};
      final vmess = {
        'tag': 'Core accepted VMess',
        'protocol': 'vmess',
        'settings': {'security': 'unknown'},
      };
      var response = <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'outbounds': [valid, vmess],
        },
        'error': '',
      };
      messenger.setMockDecodedMessageHandler(channel, (request) async {
        final json = jsonDecode((request as List).single as String) as Map;
        expect(json['apiVersion'], 3);
        expect(json['payload'], {'text': 'fixture'});
        return [jsonEncode(response)];
      });
      addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
      final rows = await XrayShareReader().parseShareText('fixture');
      expect(rows.map((row) => row.name.value), [
        'Valid',
        'Core accepted VMess',
      ]);

      for (final data in [
        null,
        {
          'outbounds': [valid],
        },
      ]) {
        response = {
          'success': false,
          'data': data,
          'error': 'no valid outbound found',
        };
        await expectLater(
          XrayShareReader().parseShareText('fixture'),
          throwsA(isA<LibXrayInvokeException>()),
        );
      }
      response = {
        'success': true,
        'data': {'outbounds': 'not a list'},
        'error': '',
      };
      await expectLater(
        AppHostApi().convertShareLinksToXrayJson('fixture'),
        throwsFormatException,
      );
    },
    skip: !(Platform.isMacOS || Platform.isIOS || Platform.isAndroid),
  );
}
