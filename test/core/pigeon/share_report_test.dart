import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/share/xray_share_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.onexray.BridgeHostApi.invoke',
    BridgeHostApi.pigeonChannelCodec,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('share reports keep real counts, add App rejections, and never infer unknown failures', () async {
    final valid = {'tag': 'Valid', 'protocol': 'freedom'};
    final rejected = {
      'tag': 'Invalid VMess',
      'protocol': 'vmess',
      'settings': {'security': 'unknown'},
    };
    var response = {
      'success': true,
      'data': <String, dynamic>{
        'config': {
          'outbounds': [valid, rejected],
        },
        'usableCount': 2,
        'failedCount': 3,
      },
      'error': '',
    };
    messenger.setMockDecodedMessageHandler(channel, (request) async {
      final json = jsonDecode((request as List).single as String) as Map;
      expect(json['apiVersion'], 4);
      expect(json['payload']['includeStats'], isTrue);
      return [jsonEncode(response)];
    });
    addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
    final report = await XrayShareReader().parseShareTextReport('fixture');
    expect(report.count, 1);
    expect(report.failureCount, 4);

    response = {
      'success': false,
      'data': {
        'config': {'outbounds': []},
        'usableCount': 0,
        'failedCount': 2,
      },
      'error': 'no usable nodes',
    };
    final empty = await XrayShareReader().parseShareTextReport('fixture');
    expect(empty.rows, isEmpty);
    expect(empty.failureCount, 2);

    response = {
      'success': true,
      'data': {
        'outbounds': [valid],
      },
      'error': '',
    };
    expect(
      (await XrayShareReader().parseShareTextReport('old library'))
          .failureCount,
      isNull,
    );

    response = {
      'success': true,
      'data': {
        'config': {
          'outbounds': [valid],
        },
        'usableCount': 2,
        'failedCount': 0,
      },
      'error': '',
    };
    await expectLater(
      AppHostApi().convertShareLinksToXrayJsonReport('invalid report'),
      throwsFormatException,
    );
  }, skip: !(Platform.isMacOS || Platform.isIOS || Platform.isAndroid));
}
