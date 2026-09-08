import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.onexray.BridgeHostApi.invoke',
    BridgeHostApi.pigeonChannelCodec,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final messages = <String?>[];
  late String response;

  setUp(() {
    messages.clear();
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
    messenger.setMockDecodedMessageHandler(channel, (request) async {
      final invoke = jsonDecode((request as List).single as String) as Map;
      expect(invoke['method'], 'testXray');
      return [response];
    });
    addTearDown(() {
      debugPrint = previousDebugPrint;
      messenger.setMockDecodedMessageHandler(channel, null);
    });
  });

  group('Invoke logging', () {
    test('failure logs the method and error without the payload', () async {
      const error =
          'testXray requires an isolated process without a managed Xray instance';
      response = jsonEncode({'success': false, 'data': null, 'error': error});

      expect(await AppHostApi().testXray('{"private":"not-for-logs"}'), error);
      expect(messages, ['libXray testXray failed: $error']);
    });

    test('success does not produce a failure log', () async {
      response = jsonEncode({'success': true, 'data': {}, 'error': ''});

      expect(await AppHostApi().testXray('{}'), '');
      expect(messages, isEmpty);
    });

    test(
      'invalid response logs the parser error, not the raw response',
      () async {
        response = 'invalid response with private contents';
        const error = LibXrayInvokeResponseParser.invalidResponseError;

        expect(await AppHostApi().testXray('{}'), error);
        expect(messages, ['libXray testXray failed: $error']);
      },
    );
  }, skip: !(Platform.isMacOS || Platform.isIOS || Platform.isAndroid));
}
