import 'package:onexray/service/xray/setting/dns_server_state.dart';
import 'package:onexray/service/xray/setting/dns_state.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/log_state.dart';
import 'package:onexray/service/xray/setting/routing_rule_state.dart';
import 'package:onexray/service/xray/setting/routing_state.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';
import 'package:onexray/service/xray/setting/state.dart';

extension XraySettingSimpleWriter on XraySettingSimple {
  XraySettingState get xraySettingState {
    final state = XraySettingState();
    state.name = XraySettingSimple.simpleName;

    if (enableLog) {
      state.log.logLevel = XrayLogLevel.info;
      state.log.dnsLog = true;
    }

    final domain = _domain;
    final ip = _ip;

    state.routing = _routingState(domain, ip);
    state.dns = _dnsState(domain);

    if (dns == SimpleDns.cloudflareDirect) {
      state.routing.dnsQueryRule.outboundTag = RoutingOutboundTag.direct.name;
      state.outbounds.dns.dialerProxy = RoutingOutboundTag.direct.name;
    } else {
      state.routing.dnsQueryRule.outboundTag = RoutingOutboundTag.proxy.name;
      state.outbounds.dns.dialerProxy = RoutingOutboundTag.proxy.name;
    }

    return state;
  }

  RoutingState _routingState(List<String> domain, List<String> ip) {
    final rules = <RoutingRuleState>[];
    if (routing.localDns) {
      final rule = RoutingRuleState();
      rule.inboundTag = <String>{DNSServerTag.localDns};
      rule.outboundTag = RoutingOutboundTag.direct.name;
      rule.ruleTag = RoutingRuleTag.localDnsDirect;
      rules.add(rule);
    }
    if (domain.isNotEmpty) {
      final rule = RoutingRuleState();
      rule.domain = domain;
      rule.outboundTag = RoutingOutboundTag.direct.name;
      rule.ruleTag = RoutingRuleTag.domainDirect;
      rules.add(rule);
    }
    if (ip.isNotEmpty) {
      final rule = RoutingRuleState();
      rule.ip = ip;
      rule.outboundTag = RoutingOutboundTag.direct.name;
      rule.ruleTag = RoutingRuleTag.ipDirect;
      rules.add(rule);
    }

    final state = RoutingState();
    state.domainStrategy = routing.domainStrategy;
    state.customRules.addAll(rules);

    return state;
  }

  DnsState _dnsState(List<String> domain) {
    final state = DnsState();
    state.queryStrategy = routing.queryStrategy;

    final server = DnsServerState();
    server.address = dns.address;
    server.queryStrategy = state.queryStrategy;
    server.tag = DNSServerTag.defaultDns;

    final servers = <DnsServerState>[server];
    if (routing.localDns) {
      final localServer = _localDns(domain);
      localServer.tag = DNSServerTag.localDns;
      localServer.queryStrategy = state.queryStrategy;
      servers.add(localServer);
      state.disableFallbackIfMatch = true;
    }
    state.servers = servers;

    return state;
  }

  DnsServerState _localDns(List<String> domain) {
    final server = DnsServerState();
    switch (routing.directSet) {
      case SimpleCountry.other:
        server.address = "tcp://1.1.1.1";
        server.domains = domain;
        break;
      case SimpleCountry.cn:
        server.address = "tcp://223.5.5.5";
        server.domains = domain;
        break;
      case SimpleCountry.ir:
        server.address = "tcp://5.200.200.200";
        server.domains = domain;
        break;
      case SimpleCountry.ru:
        server.address = "tcp://9.9.9.9";
        server.domains = domain;
        break;
    }
    return server;
  }

  List<String> get _domain {
    final domain = <String>[];
    if (routing.localDirect) {
      domain.add("geosite:PRIVATE");
    }
    if (routing.appleDirect) {
      domain.add("geosite:APPLE");
    }
    switch (routing.directSet) {
      case SimpleCountry.other:
        break;
      case SimpleCountry.cn:
        domain.add("geosite:CN");
        break;
      case SimpleCountry.ir:
        domain.add("geosite:CATEGORY-IR");
        break;
      case SimpleCountry.ru:
        domain.addAll([
          "geosite:CATEGORY-GOV-RU",
          "geosite:YANDEX",
          "geosite:MAILRU",
          r"regexp:.ru$",
        ]);
        break;
    }
    return domain;
  }

  List<String> get _ip {
    final ip = <String>[];
    if (routing.localDirect) {
      ip.add("geoip:PRIVATE");
    }
    if (routing.enableIPRule) {
      switch (routing.directSet) {
        case SimpleCountry.other:
          break;
        case SimpleCountry.cn:
          ip.add("geoip:CN");
          break;
        case SimpleCountry.ir:
          ip.add("geoip:IR");
          break;
        case SimpleCountry.ru:
          ip.add("geoip:RU");
          break;
      }
    }
    return ip;
  }
}
