import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';

void main() {
  test('round-trips the complete regular configuration model', () {
    final source = <String, dynamic>{
      'env': {'xray.location.asset': '/assets', 'xray.location.cert': '/certs'},
      'log': {
        'access': '/logs/access.log',
        'error': '/logs/error.log',
        'loglevel': 'warning',
        'dnsLog': true,
        'maskAddress': 'full',
      },
      'dns': {
        'servers': [
          {
            'address': '8.8.8.8',
            'domains': ['geosite:cn'],
            'skipFallback': true,
            'queryStrategy': 'UseIPv4',
            'tag': 'app-dns-direct',
          },
        ],
      },
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': [
          {
            'domain': ['geosite:cn'],
            'ip': ['geoip:cn'],
            'port': '80,443',
            'network': ['tcp', 'udp'],
            'inboundTag': ['tunIn'],
            'outboundTag': 'direct',
            'ruleTag': 'app-smart-cn',
          },
          {'balancerTag': 'proxy', 'ruleTag': 'app-default'},
        ],
        'balancers': [
          {
            'tag': 'proxy',
            'selector': ['app-entry-0'],
            'strategy': {'type': 'roundRobin'},
            'fallbackTag': 'block',
          },
        ],
      },
      'inbounds': [
        {
          'listen': '127.0.0.1',
          'protocol': 'tun',
          'settings': {'name': 'OneXrayTun', 'mtu': 9000},
          'tag': 'tunIn',
          'sniffing': {
            'enabled': true,
            'routeOnly': false,
            'destOverride': ['http', 'tls', 'quic'],
          },
        },
        {
          'listen': '127.0.0.1',
          'port': '1080',
          'protocol': 'socks',
          'settings': {'auth': 'noauth', 'udp': true},
          'tag': 'socksIn',
        },
      ],
      'outbounds': [
        {'tag': 'app-entry-0', 'protocol': 'freedom'},
      ],
      'policy': {
        'system': {
          'statsInboundUplink': true,
          'statsInboundDownlink': true,
          'statsOutboundUplink': false,
          'statsOutboundDownlink': false,
        },
      },
      'stats': <String, dynamic>{},
      'metrics': {'listen': '127.0.0.1:11111'},
      'observatory': {'subjectSelector': <String>[]},
    };

    expect(XrayJson.fromJson(source).toJson(), source);
  });

  test('ignores fields outside the regular model envelope', () {
    final config = XrayJson.fromJson({
      'name': 'Raw-only name',
      'api': {'tag': 'api'},
      'env': {'xray.location.asset': '/assets', 'futureEnv': true},
      'dns': {
        'hosts': {
          'node.example': ['192.0.2.1'],
        },
        'queryStrategy': 'UseIPv4',
        'servers': [
          {'address': '8.8.8.8', 'queryStrategy': 'UseIPv4'},
        ],
      },
      'routing': {
        'futureRouting': true,
        'rules': [
          {'ruleTag': 'known', 'futureRule': true},
        ],
      },
      'inbounds': [
        {
          'protocol': 'tun',
          'settings': {'name': 'OneXrayTun', 'futureSetting': true},
        },
      ],
    });

    expect(config.toJson(), {
      'env': {'xray.location.asset': '/assets'},
      'dns': {
        'servers': [
          {'address': '8.8.8.8', 'queryStrategy': 'UseIPv4'},
        ],
      },
      'routing': {
        'rules': [
          {'ruleTag': 'known'},
        ],
      },
      'inbounds': [
        {
          'protocol': 'tun',
          'settings': {'name': 'OneXrayTun', 'futureSetting': true},
        },
      ],
    });
  });

  test('preserves complete proxy outbound maps', () {
    final outbound = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': 'example.test',
            'port': 443,
            'users': [
              {'id': 'fixture', 'flow': 'xtls-rprx-vision'},
            ],
          },
        ],
      },
      'streamSettings': {
        'network': 'xhttp',
        'xhttpSettings': {
          'path': '/xray',
          'futureTransportField': {'enabled': true},
        },
      },
    };

    expect(
      XrayJson.fromJson({
        'outbounds': [outbound],
      }).toJson(),
      {
        'outbounds': [outbound],
      },
    );
  });

  test('round-trips the App-managed inbound settings', () {
    final tun = {
      'name': 'OneXrayTun',
      'mtu': 9000,
      'gateway': ['198.18.0.1/15', 'fc00::1/64'],
      'dns': ['8.8.8.8', '2001:4860:4860::8888'],
      'autoSystemRoutingTable': ['0.0.0.0/0', '::/0'],
      'autoOutboundsInterface': 'en0',
    };
    final socks = {'auth': 'noauth', 'udp': true};
    expect(XrayInboundTunSettings.fromJson(tun).toJson(), tun);
    expect(XrayInboundSocksSettings.fromJson(socks).toJson(), socks);
  });

  test('round-trips the three App-managed system outbounds', () {
    const direct = {'tag': 'direct', 'protocol': 'freedom'};
    const block = {'tag': 'block', 'protocol': 'blackhole'};
    expect(XrayOutbound.fromJson(direct).toJson(), direct);
    expect(XrayOutbound.fromJson(block).toJson(), block);

    final directWithInterface = XrayOutbound(
      tag: 'direct',
      protocol: 'freedom',
      streamSettings: XrayStreamSettings(
        sockopt: XraySockopt(interface: 'en0'),
      ),
    ).toJson();
    expect(directWithInterface, {
      'tag': 'direct',
      'protocol': 'freedom',
      'streamSettings': {
        'sockopt': {'interface': 'en0'},
      },
    });

    final dns = {
      'tag': 'dnsOut',
      'protocol': 'dns',
      'settings': {
        'rules': [
          {'action': 'hijack', 'qType': '1,28'},
          {'action': 'direct'},
        ],
      },
      'streamSettings': {
        'sockopt': {'dialerProxy': 'direct'},
      },
    };
    expect(XrayOutbound.fromJson(dns).toJson(), dns);
    expect(
      XrayOutboundDnsRule.fromJson({'action': 'hijack', 'qType': '1,28'})
          .toJson(),
      {'action': 'hijack', 'qType': '1,28'},
    );
  });

  test('keeps outbound settings as a map and minimizes stream settings', () {
    final outbound = XrayOutbound.fromJson({
      'tag': 'dnsOut',
      'protocol': 'dns',
      'settings': {'futureSetting': true},
      'streamSettings': {
        'network': 'tcp',
        'sockopt': {
          'dialerProxy': 'direct',
          'interface': 'en0',
          'futureSockopt': true,
        },
      },
    });

    expect(outbound.toJson(), {
      'tag': 'dnsOut',
      'protocol': 'dns',
      'settings': {'futureSetting': true},
      'streamSettings': {
        'sockopt': {'dialerProxy': 'direct', 'interface': 'en0'},
      },
    });
  });
}
