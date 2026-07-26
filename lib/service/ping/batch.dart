import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/raw/writer.dart';

class PingBatchSource {
  final String configText;
  final String? outboundTag;

  const PingBatchSource(this.configText, {this.outboundTag});
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
  static const _batchSize = 5;

  static Future<List<PingBatchResult>> run(
    List<PingBatchSource> sources,
    PingState pingState,
  ) async {
    if (sources.isEmpty) {
      return const [];
    }

    final results = sources
        .map((_) => PingBatchResult.failed())
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
            "Prepare ping config failed at index $index: "
            "$error\n$stackTrace",
          );
          results[index] = PingBatchResult.failed("$error");
        }
      }

      if (prepared.isEmpty) {
        return results;
      }

      for (var offset = 0; offset < prepared.length; offset += _batchSize) {
        final candidateEnd = offset + _batchSize;
        final end = candidateEnd < prepared.length
            ? candidateEnd
            : prepared.length;
        final batch = prepared.sublist(offset, end);
        final request = PingBatchRequest(
          batch
              .map(
                (item) => PingBatchItemRequest(
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
          if (responseItem.delay == null) {
            continue;
          }
          results[preparedItem.sourceIndex] = PingBatchResult(
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
