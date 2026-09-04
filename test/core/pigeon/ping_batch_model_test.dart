import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/model.dart';

void main() {
  test(
    'optional per-node location preserves zero latency and independent errors',
    () {
      final request = PingBatchRequest(
        [],
        5,
        'https://example.com/',
        locationUrl: 'https://example.com/location',
      ).toJson();
      expect(request['locationUrl'], 'https://example.com/location');
      final results = PingBatchResponse.fromJson({
        'results': [
          {
            'success': true,
            'delay': 0,
            'locationJson': '{"ip_address":"203.0.113.1","country":"US"}',
          },
          {'success': true, 'delay': 20, 'locationError': 'unavailable'},
          {
            'success': true,
            'delay': 30,
            'location': {'countryCode': 'JP'},
          },
        ],
      }).results!;
      expect(results[0].delay, 0);
      expect(
        results[0].locationJson,
        '{"ip_address":"203.0.113.1","country":"US"}',
      );
      expect(results[1].success, isTrue);
      expect(results[1].delay, 20);
      expect(results[1].locationJson, isNull);
      expect(results[1].locationError, 'unavailable');
      expect(results[2].locationJson, isNull);
    },
  );
  test('ping batch request uses the libXray wire model', () {
    final request = LibXrayInvokeRequest(
      method: LibXrayMethod.pingBatch,
      payload: PingBatchRequest(
        [PingBatchItemRequest('{"outbounds":[]}', outboundTag: 'proxy')],
        5,
        'https://cp.cloudflare.com/',
      ).toJson(),
    ).toJson();

    expect(request['apiVersion'], 4);
    expect(request['method'], 'pingBatch');
    expect(request['payload'], {
      'configs': [
        {'xrayJson': '{"outbounds":[]}', 'outboundTag': 'proxy'},
      ],
      'timeout': 5,
      'url': 'https://cp.cloudflare.com/',
    });
  });

  test('ping batch response keeps per-item failure data', () {
    final response = PingBatchResponse.fromJson({
      'results': [
        {'success': false, 'delay': 11000, 'error': 'timeout'},
      ],
    });

    final result = response.results!.single;
    expect(result.success, isFalse);
    expect(result.delay, 11000);
    expect(result.error, 'timeout');
  });
}
