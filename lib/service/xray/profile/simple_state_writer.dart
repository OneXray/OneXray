import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/map.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';

extension XrayProfileSimpleWriter on XrayProfileSimple {
  Map<String, dynamic> xrayProfileMap(String tunDnsIPv4) {
    final profile = createBaseProfileMap(name: XrayProfileSimple.simpleName);

    if (enableLog) {
      final log = profile['log'] as Map<String, dynamic>;
      log['loglevel'] = XrayLogLevel.info.name;
      log['dnsLog'] = true;
    }

    final domain = _domain;
    final ip = _ip;
    profile['dns'] = _dnsMap(domain, tunDnsIPv4);

    final routingMap = profile['routing'] as Map<String, dynamic>;
    routingMap['domainStrategy'] = routing.domainStrategy.name;
    final rules = routingMap['rules'] as List<dynamic>;
    rules.addAll(_customRoutingRules(domain, ip));

    if (fakeDns) {
      final inbounds = profile['inbounds'] as List<dynamic>;
      final tun = inbounds.first as Map<String, dynamic>;
      final sniffing = tun['sniffing'] as Map<String, dynamic>;
      final destOverride = sniffing['destOverride'] as List<String>;
      destOverride.add('fakedns+others');
    }

    final outbounds = profile['outbounds'] as List<dynamic>;
    final dnsOutbound = outbounds.last as Map<String, dynamic>;
    final streamSettings =
        dnsOutbound['streamSettings'] as Map<String, dynamic>;
    final sockopt = streamSettings['sockopt'] as Map<String, dynamic>;
    sockopt['dialerProxy'] = RoutingOutboundTag.proxy.name;

    return profile;
  }

  List<Map<String, dynamic>> _customRoutingRules(
    List<String> domain,
    List<String> ip,
  ) {
    final rules = <Map<String, dynamic>>[_defaultDnsProxyRule()];
    if (routing.localDns) {
      rules.add(<String, dynamic>{
        'inboundTag': <String>[DNSServerTag.localDns],
        'outboundTag': RoutingOutboundTag.direct.name,
        'ruleTag': RoutingRuleTag.localDnsDirect,
      });
    }
    if (routing.blockAds) {
      rules.add(<String, dynamic>{
        'domain': <String>['geosite:CATEGORY-ADS-ALL'],
        'outboundTag': RoutingOutboundTag.block.name,
        'ruleTag': RoutingRuleTag.adBlock,
      });
    }
    if (domain.isNotEmpty) {
      rules.add(<String, dynamic>{
        'domain': domain,
        'outboundTag': RoutingOutboundTag.direct.name,
        'ruleTag': RoutingRuleTag.domainDirect,
      });
    }
    if (ip.isNotEmpty) {
      rules.add(<String, dynamic>{
        'ip': ip,
        'outboundTag': RoutingOutboundTag.direct.name,
        'ruleTag': RoutingRuleTag.ipDirect,
      });
    }
    return rules;
  }

  Map<String, dynamic> _defaultDnsProxyRule() => <String, dynamic>{
    'inboundTag': <String>[DNSServerTag.defaultDns],
    'outboundTag': RoutingOutboundTag.proxy.name,
    'ruleTag': RoutingRuleTag.defaultDnsProxy,
  };

  Map<String, dynamic> _dnsMap(List<String> domain, String tunDnsIPv4) {
    final servers = <dynamic>[];
    if (fakeDns) {
      servers.add(<String, dynamic>{
        'address': 'fakedns',
        'queryStrategy': DnsQueryStrategy.useIPv4.name,
      });
    }
    servers.add(<String, dynamic>{
      'address': 'tcp://$tunDnsIPv4',
      'queryStrategy': DnsQueryStrategy.useIPv4.name,
      'tag': DNSServerTag.defaultDns,
    });
    if (routing.localDns) {
      servers.add(_localDns(domain));
    }

    return <String, dynamic>{
      'servers': servers,
      'tag': DNSServerTag.dnsQuery,
      'queryStrategy': DnsQueryStrategy.useIPv4.name,
      if (routing.localDns) 'disableFallbackIfMatch': true,
    };
  }

  Map<String, dynamic> _localDns(List<String> domain) {
    late final String address;
    switch (routing.directSet) {
      case SimpleCountry.other:
        address = 'tcp://8.8.8.8';
        break;
      case SimpleCountry.cn:
        address = 'tcp://223.5.5.5';
        break;
      case SimpleCountry.ir:
        address = 'tcp://5.200.200.200';
        break;
      case SimpleCountry.ru:
        address = 'tcp://9.9.9.9';
        break;
    }
    return <String, dynamic>{
      'address': address,
      if (domain.isNotEmpty) 'domains': domain,
      'queryStrategy': DnsQueryStrategy.useIPv4.name,
      'tag': DNSServerTag.localDns,
    };
  }

  List<String> get _domain {
    final domain = <String>[];
    if (routing.localDirect) {
      domain.add('geosite:PRIVATE');
    }
    if (routing.appleDirect) {
      domain.add('geosite:APPLE');
    }
    switch (routing.directSet) {
      case SimpleCountry.other:
        break;
      case SimpleCountry.cn:
        domain.add('geosite:CN');
        break;
      case SimpleCountry.ir:
        domain.add('geosite:CATEGORY-IR');
        break;
      case SimpleCountry.ru:
        domain.add('geosite:CATEGORY-RU');
        break;
    }
    return domain;
  }

  List<String> get _ip {
    final ip = <String>[];
    if (routing.localDirect) {
      ip.add('geoip:PRIVATE');
    }
    if (routing.enableIPRule) {
      switch (routing.directSet) {
        case SimpleCountry.other:
          break;
        case SimpleCountry.cn:
          ip.add('geoip:CN');
          break;
        case SimpleCountry.ir:
          ip.add('geoip:IR');
          break;
        case SimpleCountry.ru:
          ip.add('geoip:RU');
          break;
      }
    }
    return ip;
  }
}
