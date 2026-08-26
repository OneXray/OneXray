import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';

Map<String, dynamic> createBaseProfileMap({
  String name = XrayStateConstants.defaultName,
  String dnsServerAddress = '8.8.8.8',
}) => <String, dynamic>{
  'name': name,
  'log': <String, dynamic>{
    'access': XrayStateConstants.accessLogPath,
    'error': XrayStateConstants.errorLogPath,
    'loglevel': XrayLogLevel.none.name,
    'dnsLog': false,
  },
  'dns': <String, dynamic>{
    'servers': <dynamic>[
      <String, dynamic>{
        'address': dnsServerAddress,
        'queryStrategy': DnsQueryStrategy.useIPv4.name,
      },
    ],
    'tag': DNSServerTag.dnsQuery,
    'queryStrategy': DnsQueryStrategy.useIPv4.name,
  },
  'routing': <String, dynamic>{
    'domainStrategy': RoutingDomainStrategy.ipIfNonMatch.name,
    'rules': <dynamic>[
      <String, dynamic>{
        'inboundTag': <String>[DNSServerTag.dnsQuery],
        'outboundTag': RoutingOutboundTag.proxy.name,
        'ruleTag': RoutingRuleTag.dnsQuery,
      },
      <String, dynamic>{
        'port': '53',
        'inboundTag': <String>[RoutingInboundTag.tunIn.name],
        'outboundTag': RoutingOutboundTag.dnsOut.name,
        'ruleTag': RoutingRuleTag.dnsOut,
      },
      <String, dynamic>{
        'port': '853',
        'inboundTag': <String>[RoutingInboundTag.tunIn.name],
        'outboundTag': RoutingOutboundTag.proxy.name,
        'ruleTag': RoutingRuleTag.dnsDoT,
      },
      <String, dynamic>{
        'inboundTag': <String>[RoutingInboundTag.pingIn.name],
        'outboundTag': RoutingOutboundTag.proxy.name,
        'ruleTag': RoutingRuleTag.ping,
      },
    ],
  },
  'inbounds': <dynamic>[createTunInboundMap(), createPingInboundMap()],
  'outbounds': <dynamic>[
    <String, dynamic>{
      'protocol': XrayOutboundProtocol.freedom.name,
      'tag': RoutingOutboundTag.direct.name,
    },
    <String, dynamic>{
      'protocol': XrayOutboundProtocol.freedom.name,
      'tag': RoutingOutboundTag.fragment.name,
    },
    <String, dynamic>{
      'protocol': XrayOutboundProtocol.blackhole.name,
      'tag': RoutingOutboundTag.block.name,
    },
    <String, dynamic>{
      'protocol': XrayOutboundProtocol.dns.name,
      'settings': <String, dynamic>{
        'rules': <dynamic>[
          <String, dynamic>{'action': 'hijack', 'qType': '1,28'},
          <String, dynamic>{'action': 'direct'},
        ],
      },
      'tag': RoutingOutboundTag.dnsOut.name,
      'streamSettings': <String, dynamic>{
        'sockopt': <String, dynamic>{
          'dialerProxy': RoutingOutboundTag.direct.name,
        },
      },
    },
  ],
  'fakeDns': <dynamic>[
    <String, dynamic>{'ipPool': '198.18.0.0/15', 'poolSize': 32768},
  ],
};
