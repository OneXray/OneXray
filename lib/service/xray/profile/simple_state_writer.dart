import 'package:onexray/service/xray/profile/dns_server_state.dart';
import 'package:onexray/service/xray/profile/dns_state.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/profile/log_state.dart';
import 'package:onexray/service/xray/profile/routing_rule_state.dart';
import 'package:onexray/service/xray/profile/routing_state.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:onexray/service/xray/profile/state.dart';

extension XrayProfileSimpleWriter on XrayProfileSimple {
  XrayProfileState get xrayProfileState {
    final state = XrayProfileState();
    state.name = XrayProfileSimple.simpleName;

    if (enableLog) {
      state.log.logLevel = XrayLogLevel.info;
      state.log.dnsLog = true;
    }

    final domain = _domain;
    final ip = _ip;

    state.routing = _routingState(domain, ip);
    state.dns = _dnsState(domain);
    if (fakeDns) {
      state.inbounds.tun.sniffing.destOverride.add(
        InboundSniffingDestOverride.fakednsOthers,
      );
    }

    state.routing.dnsQueryRule.outboundTag = RoutingOutboundTag.proxy.name;
    state.outbounds.dns.dialerProxy = RoutingOutboundTag.proxy.name;

    return state;
  }

  RoutingState _routingState(List<String> domain, List<String> ip) {
    final rules = <RoutingRuleState>[_defaultDnsProxyRule()];
    if (routing.localDns) {
      final rule = RoutingRuleState();
      rule.inboundTag = <String>{DNSServerTag.localDns};
      rule.outboundTag = RoutingOutboundTag.direct.name;
      rule.ruleTag = RoutingRuleTag.localDnsDirect;
      rules.add(rule);
    }
    if (routing.blockAds) {
      rules.add(_adBlockRule());
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

  RoutingRuleState _defaultDnsProxyRule() {
    final rule = RoutingRuleState();
    rule.inboundTag = <String>{DNSServerTag.defaultDns};
    rule.outboundTag = RoutingOutboundTag.proxy.name;
    rule.ruleTag = RoutingRuleTag.defaultDnsProxy;
    return rule;
  }

  RoutingRuleState _adBlockRule() {
    final rule = RoutingRuleState();
    rule.domain = ["geosite:CATEGORY-ADS-ALL"];
    rule.outboundTag = RoutingOutboundTag.block.name;
    rule.ruleTag = RoutingRuleTag.adBlock;
    return rule;
  }

  DnsState _dnsState(List<String> domain) {
    final state = DnsState();

    final server = DnsServerState();
    server.address = dns.address;
    server.tag = DNSServerTag.defaultDns;

    final servers = <DnsServerState>[];
    if (fakeDns) {
      servers.add(_fakeDnsServer());
    }
    servers.add(server);
    if (routing.localDns) {
      final localServer = _localDns(domain);
      localServer.tag = DNSServerTag.localDns;
      servers.add(localServer);
      state.disableFallbackIfMatch = true;
    }
    state.servers = servers;

    return state;
  }

  DnsServerState _fakeDnsServer() {
    final server = DnsServerState();
    server.address = "fakedns";
    return server;
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
        domain.add("geosite:CATEGORY-RU");
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
