import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/raw/writer.dart';

class PingBatchSource {
  final String id;
  final String configText;
  final String? outboundTag;

  const PingBatchSource(this.id, this.configText, {this.outboundTag});
}

class PingBatchResult {
  final String id;
  final bool success;
  final int delay;
  final String error;

  const PingBatchResult(this.id, this.success, this.delay, this.error);

  factory PingBatchResult.failed(String id, [String error = ""]) =>
      PingBatchResult(id, false, PingDelayConstants.error, error);
}

class PingBatchRunner {
  static const _maxConfigsPerRequest = 5;

  static Future<List<PingBatchResult>> run(
    List<PingBatchSource> sources,
    PingState pingState,
  ) async {
    if (sources.isEmpty) {
      return const [];
    }

    final results = sources
        .map((source) => PingBatchResult.failed(source.id))
        .toList(growable: false);
    final prepared = <_PreparedPingSource>[];

    try {
      for (var index = 0; index < sources.length; index++) {
        final source = sources[index];
        try {
          final configPath = await XrayRawWriter.writeConfig(source.configText);
          prepared.add(_PreparedPingSource(index, source, configPath));
        } catch (error, stackTrace) {
          ygLogger(
            "Prepare ping config failed: ${source.id}, $error\n$stackTrace",
          );
          results[index] = PingBatchResult.failed(source.id, "$error");
        }
      }

      if (prepared.isEmpty) {
        return results;
      }

      final configuredBatchSize = pingState.concurrency.toInt();
      final batchSize = configuredBatchSize < 1
          ? 1
          : configuredBatchSize > _maxConfigsPerRequest
          ? _maxConfigsPerRequest
          : configuredBatchSize;
      for (var offset = 0; offset < prepared.length; offset += batchSize) {
        final candidateEnd = offset + batchSize;
        final end = candidateEnd < prepared.length
            ? candidateEnd
            : prepared.length;
        final batch = prepared.sublist(offset, end);
        final request = PingBatchRequest(
          batch
              .map(
                (item) => PingBatchItemRequest(
                  item.source.id,
                  item.configPath,
                  outboundTag: item.source.outboundTag,
                ),
              )
              .toList(growable: false),
          pingState.timeout.toInt(),
          pingState.realUrl,
        );
        final response = await AppHostApi().pingBatch(request);
        final responseResults = response?.results;
        if (responseResults == null || responseResults.length != batch.length) {
          continue;
        }

        for (var index = 0; index < batch.length; index++) {
          final preparedItem = batch[index];
          final responseItem = responseResults[index];
          if (responseItem.id != preparedItem.source.id ||
              responseItem.delay == null) {
            continue;
          }
          results[preparedItem.sourceIndex] = PingBatchResult(
            preparedItem.source.id,
            responseItem.success ?? false,
            responseItem.delay!,
            responseItem.error ?? "",
          );
        }
      }
      return results;
    } finally {
      for (final item in prepared) {
        try {
          await FileTool.deleteFileIfExists(item.configPath);
        } catch (error, stackTrace) {
          ygLogger(
            "Delete ping config failed: ${item.configPath}, "
            "$error\n$stackTrace",
          );
        }
      }
    }
  }
}

class _PreparedPingSource {
  final int sourceIndex;
  final PingBatchSource source;
  final String configPath;

  const _PreparedPingSource(this.sourceIndex, this.source, this.configPath);
}
