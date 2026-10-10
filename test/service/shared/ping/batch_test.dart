import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/shared/ping/batch.dart';
import 'package:onexray/service/shared/ping/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("empty ping batch returns no results", () async {
    final results = await PingBatchRunner.run(const [], PingState());

    expect(results, isEmpty);
  });

  test(
    'native request omits location by default and adds it only when enabled',
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
        expect(json['method'], 'pingBatch');
        payloads.add(json['payload'] as Map);
        return [
          jsonEncode({
            'success': true,
            'error': '',
            'data': {
              'results': [
                {'success': true, 'delay': 0},
                {'success': true, 'delay': 20},
              ],
            },
          }),
        ];
      });
      addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
      const sources = [
        PingBatchSource('{"outbounds":[]}', outboundTag: 'proxy'),
        PingBatchSource('{"outbounds":[{"protocol":"freedom"}]}'),
      ];
      final state = PingState()
        ..timeout = 8
        ..url = PingUrl.custom
        ..customUrl = 'https://example.com/ping';

      final first = await PingBatchRunner.run(sources, state);
      state.locationEnabled = true;
      await PingBatchRunner.run(sources, state);
      state.locationEnabled = false;
      await PingBatchRunner.run(sources, state);

      final expected = {
        'configs': [
          {'xrayJson': sources[0].xrayJson, 'outboundTag': 'proxy'},
          {'xrayJson': sources[1].xrayJson},
        ],
        'timeout': 8,
        'url': 'https://example.com/ping',
      };
      expect(payloads, [
        expected,
        {...expected, 'locationUrl': NetClient.geoIPUrl},
        expected,
      ]);
      expect(first.map((result) => result.delay), [0, 20]);
    },
    skip: !(Platform.isMacOS || Platform.isIOS || Platform.isAndroid),
  );

  test('location JSON is parsed per item without changing delay results', () {
    final responses = [
      PingBatchItemResponse(
        true,
        12,
        '',
        locationJson: '{"ip_address":"203.0.113.1","country":" jp "}',
      ),
      PingBatchItemResponse(true, 18, '', locationJson: 'not JSON'),
      PingBatchItemResponse(true, 24, '', locationJson: '{"country":"USA"}'),
      PingBatchItemResponse(true, 30, '', locationError: 'unavailable'),
      PingBatchItemResponse(
        false,
        10000,
        'timeout',
        locationJson: '{"country":"sg"}',
      ),
    ];

    final results = responses.map(PingBatchResult.fromResponse).toList();

    expect(results[0].countryCode, 'JP');
    expect(results[0].locationError, isNull);
    expect(results[0].delay, 12);
    expect(results[1].countryCode, isNull);
    expect(results[1].locationError, 'invalid location response');
    expect(results[1].delay, 18);
    expect(results[2].countryCode, isNull);
    expect(results[2].locationError, 'invalid location response');
    expect(results[2].delay, 24);
    expect(results[3].locationError, 'unavailable');
    expect(results[3].delay, 30);
    expect(results[4].success, isFalse);
    expect(results[4].error, 'timeout');
    expect(results[4].countryCode, 'SG');
    expect(results[4].delay, 10000);
  });
}
