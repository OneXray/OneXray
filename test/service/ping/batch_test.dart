import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/ping/batch.dart';
import 'package:onexray/service/ping/state.dart';

void main() {
  test("empty ping batch returns no results", () async {
    final results = await PingBatchRunner.run(const [], PingState());

    expect(results, isEmpty);
  });

  test("ping batch rejects more than five configs", () async {
    final sources = List.generate(
      PingBatchRunner.maxBatchSize + 1,
      (_) => const PingBatchSource("{}"),
    );

    await expectLater(
      PingBatchRunner.run(sources, PingState()),
      throwsArgumentError,
    );
  });

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
