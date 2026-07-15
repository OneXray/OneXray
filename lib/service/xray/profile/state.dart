import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/profile/dns_state.dart';
import 'package:onexray/service/xray/profile/fake_dns_state.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/profile/log_state.dart';
import 'package:onexray/service/xray/profile/metrics_state.dart';
import 'package:onexray/service/xray/profile/outbounds_state.dart';
import 'package:onexray/service/xray/profile/routing_state.dart';

abstract final class RoutingRuleTag {
  static const dnsQuery = "dnsQuery";
  static const dnsOut = "dnsOut";
  static const dnsDoT = "dnsDoT";
  static const ping = "ping";
  static const localDnsDirect = "localDnsDirect";
  static const defaultDnsProxy = "defaultDnsProxy";
  static const adBlock = "adBlock";
  static const domainDirect = "domainDirect";
  static const ipDirect = "IPDirect";
  static const routingMode = "routingMode";
}

abstract final class DNSServerTag {
  static const dnsQuery = "dnsQuery";
  static const localDns = "localDns";
  static const defaultDns = "defaultDns";
}

class XrayProfileState {
  var name = XrayStateConstants.defaultName;

  var log = LogState();
  var dns = DnsState();
  var fakeDns = FakeDnsPoolsState();
  var routing = RoutingState();
  var inbounds = InboundsState();
  var outbounds = OutboundsState();
  var policy = PolicyState();
  var stats = StatsState();
  var metrics = MetricsState();
}
