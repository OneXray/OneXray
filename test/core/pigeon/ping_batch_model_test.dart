import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/model.dart';

void main() {
  test('ping batch request uses the libXray wire model', () {
    final request = LibXrayInvokeRequest(
      method: LibXrayMethod.pingBatch,
      payload: PingBatchRequest(
        [PingBatchItemRequest('/tmp/node-1.json', outboundTag: 'proxy')],
        5,
        'https://cp.cloudflare.com/',
      ).toJson(),
    ).toJson();

    expect(request['apiVersion'], 1);
    expect(request['method'], 'pingBatch');
    expect(request['payload'], {
      'configs': [
        {'configPath': '/tmp/node-1.json', 'outboundTag': 'proxy'},
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
