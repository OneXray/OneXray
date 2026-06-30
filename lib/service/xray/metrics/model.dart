import 'package:json_annotation/json_annotation.dart';
import 'package:onexray/service/core_run_mode/state.dart';

part 'model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayMetricsVars {
  final XrayMetricsStats? stats;

  const XrayMetricsVars(this.stats);

  XrayTrafficCounter? get tunIn => stats?.inbound?.tunIn;

  XrayTrafficCounter? totalForMode(CoreRunMode mode) {
    final inbound = stats?.inbound;
    if (inbound == null) {
      return null;
    }
    switch (mode) {
      case CoreRunMode.tun:
        return inbound.tunIn;
      case CoreRunMode.proxy:
        return XrayTrafficCounter.sum([inbound.socksIn, inbound.httpIn]);
    }
  }

  factory XrayMetricsVars.fromJson(Map<String, dynamic> json) =>
      _$XrayMetricsVarsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayMetricsVarsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayMetricsStats {
  final XrayMetricsInboundStats? inbound;

  const XrayMetricsStats(this.inbound);

  factory XrayMetricsStats.fromJson(Map<String, dynamic> json) =>
      _$XrayMetricsStatsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayMetricsStatsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayMetricsInboundStats {
  final XrayTrafficCounter? tunIn;
  final XrayTrafficCounter? socksIn;
  final XrayTrafficCounter? httpIn;

  const XrayMetricsInboundStats(this.tunIn, this.socksIn, this.httpIn);

  factory XrayMetricsInboundStats.fromJson(Map<String, dynamic> json) =>
      _$XrayMetricsInboundStatsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayMetricsInboundStatsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayTrafficCounter {
  final int? uplink;
  final int? downlink;

  const XrayTrafficCounter(this.uplink, this.downlink);

  static XrayTrafficCounter? sum(List<XrayTrafficCounter?> counters) {
    var hasValue = false;
    var uplink = 0;
    var downlink = 0;
    for (final counter in counters) {
      final nextUplink = counter?.uplink;
      final nextDownlink = counter?.downlink;
      if (nextUplink == null || nextDownlink == null) {
        continue;
      }
      hasValue = true;
      uplink += nextUplink;
      downlink += nextDownlink;
    }
    if (!hasValue) {
      return null;
    }
    return XrayTrafficCounter(uplink, downlink);
  }

  factory XrayTrafficCounter.fromJson(Map<String, dynamic> json) =>
      _$XrayTrafficCounterFromJson(json);

  Map<String, dynamic> toJson() => _$XrayTrafficCounterToJson(this);
}
