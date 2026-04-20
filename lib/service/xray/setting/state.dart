import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/setting/dns_state.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';
import 'package:onexray/service/xray/setting/log_state.dart';
import 'package:onexray/service/xray/setting/outbounds_state.dart';
import 'package:onexray/service/xray/setting/routing_state.dart';

abstract final class RoutingRuleTag {
  static const dnsQuery = "dnsQuery";
  static const dnsOut = "dnsOut";
  static const dnsDoT = "dnsDoT";
  static const ping = "ping";
  static const localDnsDirect = "localDnsDirect";
  static const domainDirect = "domainDirect";
  static const ipDirect = "IPDirect";
}

abstract final class DNSServerTag {
  static const dnsQuery = "dnsQuery";
  static const localDns = "localDns";
  static const defaultDns = "defaultDns";
}

class XraySettingState {
  var name = XrayStateConstants.defaultName;

  var log = LogState();
  var dns = DnsState();
  var routing = RoutingState();
  var inbounds = InboundsState();
  var outbounds = OutboundsState();
}
