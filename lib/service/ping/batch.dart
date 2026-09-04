import 'dart:convert';

import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/network/client.dart';
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
  final String? countryCode;
  final String? locationError;

  const PingBatchResult(
    this.success,
    this.delay,
    this.error, {
    this.countryCode,
    this.locationError,
  });

  factory PingBatchResult.failed([String error = ""]) =>
      PingBatchResult(false, PingDelayConstants.error, error);

  factory PingBatchResult.fromResponse(PingBatchItemResponse response) {
    if (response.delay == null) {
      return PingBatchResult.failed(response.error ?? "");
    }

    String? countryCode;
    var locationError = response.locationError;
    if (response.locationJson != null) {
      try {
        final location = jsonDecode(response.locationJson!);
        final country = location is Map<String, dynamic>
            ? location['country']
            : null;
        final normalized = country is String
            ? country.trim().toUpperCase()
            : '';
        if (RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) {
          countryCode = normalized;
        } else {
          locationError = 'invalid location response';
        }
      } on FormatException {
        locationError = 'invalid location response';
      }
    }

    return PingBatchResult(
      response.success ?? false,
      response.delay!,
      response.error ?? "",
      countryCode: countryCode,
      locationError: locationError,
    );
  }
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
      locationUrl: NetClient.geoIPUrl,
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
        .map(PingBatchResult.fromResponse)
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
