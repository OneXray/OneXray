import 'package:onexray/core/model/xray_json.dart';

extension XrayJsonStandard on XrayJson {
  static XrayJson get standard => XrayJson(null, null, null, null, null, null);
}

extension XrayLogStandard on XrayLog {
  static XrayLog get standard => XrayLog(null, null, null, null, null);
}

extension XrayDnsStandard on XrayDns {
  static XrayDns get standard =>
      XrayDns(null, null, null, null, null, null, null, null);
}

extension XrayDnsServerStandard on XrayDnsServer {
  static XrayDnsServer get standard =>
      XrayDnsServer(null, null, null, null, null, null, null, null, null, null);
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
  );
}

extension XrayInboundStandard on XrayInbound {
  static XrayInbound get standard =>
      XrayInbound(null, null, null, null, null, null);
}

extension XrayInboundSniffingStandard on XrayInboundSniffing {
  static XrayInboundSniffing get standard =>
      XrayInboundSniffing(null, null, null);
}

extension XrayInboundTunStandard on XrayInboundTun {
  static XrayInboundTun get standard => XrayInboundTun(null, null);
}

extension XrayOutboundStandard on XrayOutbound {
  static XrayOutbound get standard =>
      XrayOutbound(null, null, null, null, null, null, null);
}

extension XrayOutboundShadowsocksStandard on XrayOutboundShadowsocks {
  static XrayOutboundShadowsocks get standard =>
      XrayOutboundShadowsocks(null, null, null, null, null, null);
}

extension XrayOutboundSocksStandard on XrayOutboundSocks {
  static XrayOutboundSocks get standard =>
      XrayOutboundSocks(null, null, null, null);
}

extension XrayOutboundTrojanStandard on XrayOutboundTrojan {
  static XrayOutboundTrojan get standard =>
      XrayOutboundTrojan(null, null, null);
}

extension XrayOutboundVLESSStandard on XrayOutboundVLESS {
  static XrayOutboundVLESS get standard =>
      XrayOutboundVLESS(null, null, null, null, null, null);
}

extension XrayOutboundVLESSReverseStandard on XrayOutboundVLESSReverse {
  static XrayOutboundVLESSReverse get standard =>
      XrayOutboundVLESSReverse(null);
}

extension XrayOutboundVMessStandard on XrayOutboundVMess {
  static XrayOutboundVMess get standard =>
      XrayOutboundVMess(null, null, null, null);
}

extension XrayOutboundHysteriaStandard on XrayOutboundHysteria {
  static XrayOutboundHysteria get standard =>
      XrayOutboundHysteria(null, null, null);
}

extension XrayOutboundFreedomStandard on XrayOutboundFreedom {
  static XrayOutboundFreedom get standard => XrayOutboundFreedom(null, null);
}

extension XrayOutboundFreedomFragmentStandard on XrayOutboundFreedomFragment {
  static XrayOutboundFreedomFragment get standard =>
      XrayOutboundFreedomFragment(null, null, null);
}

extension XrayOutboundFreedomNoisesStandard on XrayOutboundFreedomNoises {
  static XrayOutboundFreedomNoises get standard =>
      XrayOutboundFreedomNoises(null, null, null);
}

extension XrayOutboundDnsStandard on XrayOutboundDns {
  static XrayOutboundDns get standard =>
      XrayOutboundDns(null, null, null, null);
}

extension XrayStreamSettingsStandard on XrayStreamSettings {
  static XrayStreamSettings get standard => XrayStreamSettings(
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

extension XrayTlsSettingsStandard on XrayTlsSettings {
  static XrayTlsSettings get standard =>
      XrayTlsSettings(null, null, null, null, null, null, null);
}

extension XrayRealitySettingsStandard on XrayRealitySettings {
  static XrayRealitySettings get standard =>
      XrayRealitySettings(null, null, null, null, null, null, null, null);
}

extension XrayRawSettingsStandard on XrayRawSettings {
  static XrayRawSettings get standard => XrayRawSettings(null);
}

extension XrayRawSettingsHeaderStandard on XrayRawSettingsHeader {
  static XrayRawSettingsHeader get standard =>
      XrayRawSettingsHeader(null, null);
}

extension XrayRawSettingsHeaderRequestStandard on XrayRawSettingsHeaderRequest {
  static XrayRawSettingsHeaderRequest get standard =>
      XrayRawSettingsHeaderRequest(null, null);
}

extension XrayRawSettingsHeaderRequestHeadersStandard
    on XrayRawSettingsHeaderRequestHeaders {
  static XrayRawSettingsHeaderRequestHeaders get standard =>
      XrayRawSettingsHeaderRequestHeaders(null);
}

extension XrayKcpHeaderStandard on XrayKcpHeader {
  static XrayKcpHeader get standard => XrayKcpHeader(null, null);
}

extension XrayKcpSettingsStandard on XrayKcpSettings {
  static XrayKcpSettings get standard => XrayKcpSettings(null, null);
}

extension XrayWsSettingsStandard on XrayWsSettings {
  static XrayWsSettings get standard => XrayWsSettings(null, null);
}

extension XrayGrpcSettingsStandard on XrayGrpcSettings {
  static XrayGrpcSettings get standard => XrayGrpcSettings(null, null, null);
}

extension XrayHttpupgradeSettingsStandard on XrayHttpupgradeSettings {
  static XrayHttpupgradeSettings get standard =>
      XrayHttpupgradeSettings(null, null);
}

extension XrayXhttpSettingsStandard on XrayXhttpSettings {
  static XrayXhttpSettings get standard => XrayXhttpSettings(
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

extension XrayXhttpSettingsXmuxStandard on XrayXhttpSettingsXmux {
  static XrayXhttpSettingsXmux get standard =>
      XrayXhttpSettingsXmux(null, null, null, null, null, null);
}

extension XrayHysteriaSettingsStandard on XrayHysteriaSettings {
  static XrayHysteriaSettings get standard =>
      XrayHysteriaSettings(null, null, null, null, null);
}

extension XrayHysteriaSettingsUdphopStandard on XrayHysteriaSettingsUdphop {
  static XrayHysteriaSettingsUdphop get standard =>
      XrayHysteriaSettingsUdphop(null, null);
}

extension XraySockoptStandard on XraySockopt {
  static XraySockopt get standard => XraySockopt(null, null, null, null);
}

extension XrayMuxStandard on XrayMux {
  static XrayMux get standard => XrayMux(null, null, null, null);
}
