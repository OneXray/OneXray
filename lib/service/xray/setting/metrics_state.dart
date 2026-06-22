import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/xray/standard.dart';

class MetricsState {
  var enabled = true;
  var listen = "127.0.0.1:0";

  XrayMetrics? get xrayJson {
    if (!enabled) {
      return null;
    }
    final metrics = XrayMetricsStandard.standard;
    metrics.listen = listen;
    return metrics;
  }

  void readFromXrayJson(XrayJson xrayJson) {
    final metrics = xrayJson.metrics;
    if (metrics != null && EmptyTool.checkString(metrics.listen)) {
      enabled = true;
      listen = metrics.listen!;
      return;
    }
    enabled = false;
  }

  MetricsState get copy {
    return MetricsState()
      ..enabled = enabled
      ..listen = listen;
  }

  String get displayListen => listen;
}

class StatsState {
  var enabled = true;

  XrayStats? get xrayJson => enabled ? XrayStatsStandard.standard : null;
}

class PolicyState {
  var levels = <String, XrayPolicyLevel>{};
  var system = PolicySystemState();

  XrayPolicy get xrayJson {
    final policy = XrayPolicyStandard.standard;
    if (levels.isNotEmpty) {
      policy.levels = levels;
    }
    policy.system = system.xrayJson;
    return policy;
  }
}

class PolicySystemState {
  var statsInboundUplink = true;
  var statsInboundDownlink = true;
  var statsOutboundUplink = true;
  var statsOutboundDownlink = true;

  XrayPolicySystem get xrayJson {
    final system = XrayPolicySystemStandard.standard;
    system.statsInboundUplink = statsInboundUplink;
    system.statsInboundDownlink = statsInboundDownlink;
    system.statsOutboundUplink = statsOutboundUplink;
    system.statsOutboundDownlink = statsOutboundDownlink;
    return system;
  }
}
