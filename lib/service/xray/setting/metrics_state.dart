import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/xray/standard.dart';

class MetricsState {
  var listen = "127.0.0.1:0";

  XrayMetrics get xrayJson {
    final metrics = XrayMetricsStandard.standard;
    metrics.listen = listen;
    return metrics;
  }

  void readFromXrayJson(XrayJson xrayJson) {
    final metrics = xrayJson.metrics;
    if (metrics != null && EmptyTool.checkString(metrics.listen)) {
      listen = metrics.listen!;
    }
  }

  MetricsState get copy {
    return MetricsState()..listen = listen;
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
