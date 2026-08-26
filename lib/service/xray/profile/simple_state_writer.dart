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
    final address = switch (routing.directSet) {
      SimpleCountry.other => 'tcp://8.8.8.8',
      SimpleCountry.cn => 'tcp://223.5.5.5',
      SimpleCountry.ir => 'tcp://5.200.200.200',
      SimpleCountry.ru => 'tcp://9.9.9.9',
    };
    return <String, dynamic>{
      'address': address,
      if (domain.isNotEmpty) 'domains': domain,
      'queryStrategy': DnsQueryStrategy.useIPv4.name,
      'tag': DNSServerTag.localDns,
    };
  }

  List<String> get _domain {
    final countryDomain = switch (routing.directSet) {
      SimpleCountry.other => null,
      SimpleCountry.cn => 'geosite:CN',
      SimpleCountry.ir => 'geosite:CATEGORY-IR',
      SimpleCountry.ru => 'geosite:CATEGORY-RU',
    };
    return <String>[
      if (routing.localDirect) 'geosite:PRIVATE',
      if (routing.appleDirect) 'geosite:APPLE',
      ?countryDomain,
    ];
  }

  List<String> get _ip {
    final countryIp = switch (routing.directSet) {
      SimpleCountry.other => null,
      SimpleCountry.cn => 'geoip:CN',
      SimpleCountry.ir => 'geoip:IR',
      SimpleCountry.ru => 'geoip:RU',
    };
    return <String>[
      if (routing.localDirect) 'geoip:PRIVATE',
      if (routing.enableIPRule && countryIp != null) countryIp,
    ];
  }
}
