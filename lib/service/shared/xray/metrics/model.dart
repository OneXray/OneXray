import 'package:json_annotation/json_annotation.dart';
import 'package:onexray/service/shared/xray/runtime_inbounds.dart';

part 'model.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayMetricsVars {
  final XrayMetricsStats? stats;

  const XrayMetricsVars(this.stats);

  ({int uplink, int downlink}) get managedTraffic {
    final inbound = stats?.inbound;
    return (
      uplink: (inbound?.tunIn?.uplink ?? 0) + (inbound?.lanProxy?.uplink ?? 0),
      downlink:
          (inbound?.tunIn?.downlink ?? 0) + (inbound?.lanProxy?.downlink ?? 0),
    );
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
  @JsonKey(name: lanProxyInboundTag)
  final XrayTrafficCounter? lanProxy;

  const XrayMetricsInboundStats(this.tunIn, {this.lanProxy});

  factory XrayMetricsInboundStats.fromJson(Map<String, dynamic> json) =>
      _$XrayMetricsInboundStatsFromJson(json);

  Map<String, dynamic> toJson() => _$XrayMetricsInboundStatsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class XrayTrafficCounter {
  final int? uplink;
  final int? downlink;

  const XrayTrafficCounter(this.uplink, this.downlink);

  factory XrayTrafficCounter.fromJson(Map<String, dynamic> json) =>
      _$XrayTrafficCounterFromJson(json);

  Map<String, dynamic> toJson() => _$XrayTrafficCounterToJson(this);
}
