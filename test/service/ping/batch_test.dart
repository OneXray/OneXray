import 'package:flutter_test/flutter_test.dart';
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
}
