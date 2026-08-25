import 'package:onexray/core/model/xray_json.dart';

extension XrayJsonStandard on XrayJson {
  static XrayJson get standard => XrayJson(
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
  );
}

extension XrayLogStandard on XrayLog {
  static XrayLog get standard => XrayLog(null, null, null, null, null);
}

extension XrayPolicyStandard on XrayPolicy {
  static XrayPolicy get standard => XrayPolicy(null, null);
}

extension XrayPolicyLevelStandard on XrayPolicyLevel {
  static XrayPolicyLevel get standard =>
      XrayPolicyLevel(null, null, null, null, null, null, null, null);
}

extension XrayPolicySystemStandard on XrayPolicySystem {
  static XrayPolicySystem get standard =>
      XrayPolicySystem(null, null, null, null);
}

extension XrayStatsStandard on XrayStats {
  static XrayStats get standard => XrayStats();
}

extension XrayMetricsStandard on XrayMetrics {
  static XrayMetrics get standard => XrayMetrics(null);
}

extension XrayDnsStandard on XrayDns {
  static XrayDns get standard => XrayDns(
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
  );
}

extension XrayDnsServerStandard on XrayDnsServer {
  static XrayDnsServer get standard => XrayDnsServer(
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
  );
}

extension XrayRoutingStandard on XrayRouting {
  static XrayRouting get standard => XrayRouting(null, null);
}

extension XrayRoutingRuleStandard on XrayRoutingRule {
  static XrayRoutingRule get standard => XrayRoutingRule(
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
  );
}

extension XrayInboundStandard on XrayInbound {
  static XrayInbound get standard =>
      XrayInbound(null, null, null, null, null, null);
}

extension XrayInboundSniffingStandard on XrayInboundSniffing {
  static XrayInboundSniffing get standard =>
      XrayInboundSniffing(null, null, null, null, null, null);
}

extension XrayInboundTunStandard on XrayInboundTun {
  static XrayInboundTun get standard =>
      XrayInboundTun(null, null, null, null, null, null);
}

extension XrayOutboundStandard on XrayOutbound {
  static XrayOutbound get standard => XrayOutbound(null, null, null, null);
}

extension XrayOutboundFreedomStandard on XrayOutboundFreedom {
  static XrayOutboundFreedom get standard => XrayOutboundFreedom(null);
}

extension XrayOutboundFreedomFragmentStandard on XrayOutboundFreedomFragment {
  static XrayOutboundFreedomFragment get standard =>
      XrayOutboundFreedomFragment(null, null, null);
}

extension XrayOutboundDnsStandard on XrayOutboundDns {
  static XrayOutboundDns get standard =>
      XrayOutboundDns(null, null, null, null);
}

extension XrayStreamSettingsStandard on XrayStreamSettings {
  static XrayStreamSettings get standard => XrayStreamSettings(null);
}

extension XraySockoptStandard on XraySockopt {
  static XraySockopt get standard => XraySockopt(null, null);
}

extension XrayFakeDnsStandard on XrayFakeDns {
  static XrayFakeDns get standard => XrayFakeDns(null, null);
}
