import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/ping/state.dart';

class PingBatchSource {
  final String xrayJson;
  final String? outboundTag;

  const PingBatchSource(this.xrayJson, {this.outboundTag});
}

class PingBatchResult {
  final bool success;
  final int delay;
  final String error;

  const PingBatchResult(this.success, this.delay, this.error);

  factory PingBatchResult.failed([String error = ""]) =>
      PingBatchResult(false, PingDelayConstants.error, error);
}

class PingBatchRunner {
  static const maxBatchSize = 5;

  static Future<List<PingBatchResult>> run(
    List<PingBatchSource> sources,
    PingState pingState,
  ) async {
    if (sources.isEmpty) {
      return const [];
    }
    if (sources.length > maxBatchSize) {
      throw ArgumentError.value(
        sources.length,
        "sources.length",
        "Ping batch supports at most $maxBatchSize configs",
      );
    }

    final request = PingBatchRequest(
      sources
          .map(
            (source) => PingBatchItemRequest(
              source.xrayJson,
              outboundTag: source.outboundTag,
            ),
          )
          .toList(growable: false),
      pingState.timeout.toInt(),
      pingState.realUrl,
    );
    final response = await AppHostApi().pingBatch(request);
    final responseResults = response?.results;
    if (responseResults == null || responseResults.length != sources.length) {
      return List.generate(
        sources.length,
        (_) => PingBatchResult.failed(),
        growable: false,
      );
    }

    return responseResults
        .map(
          (result) => result.delay == null
              ? PingBatchResult.failed(result.error ?? "")
              : PingBatchResult(
                  result.success ?? false,
                  result.delay!,
                  result.error ?? "",
                ),
        )
        .toList(growable: false);
  }

  static Future<PingBatchResult?> runSingle(
    PingBatchSource source,
    PingState pingState,
  ) async {
    final results = await run([source], pingState);
    return results.isEmpty ? null : results.first;
  }
}
