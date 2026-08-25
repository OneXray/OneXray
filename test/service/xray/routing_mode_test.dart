import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/core_routing_mode.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/model/xray_standard.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/routing_mode.dart';

void main() {
  test('XrayJson preserves outbound maps through JSON conversion', () {
    final source = <String, dynamic>{
      'name': 'map-round-trip',
      'outbounds': <dynamic>[
        <String, dynamic>{
          'protocol': 'vless',
          'tag': RoutingOutboundTag.proxy.name,
          'settings': <String, dynamic>{
            'appUnprojectedSetting': <String, dynamic>{'keep': true},
          },
          'streamSettings': <String, dynamic>{
            'network': 'xhttp',
            'xhttpSettings': <String, dynamic>{'appUnprojected': 1},
          },
        },
      ],
    };

    final xray = XrayJson.fromJson(_snapshotMap(source));

    expect(xray.outbounds, source['outbounds']);
    expect(xray.toJson(), source);
  });

  test('Rule mode leaves the final config unchanged', () {
    final xray = _runtimeConfig();
    final original = _snapshot(xray.toJson());
    final originalOutbounds = xray.outbounds;

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.rule),
      true,
    );

    expect(xray.toJson(), original);
    expect(identical(xray.outbounds, originalOutbounds), true);
  });

  test('Global mode removes DNS and routing and keeps only proxy', () {
    final xray = _runtimeConfig();

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.global),
      true,
    );

    expect(xray.dns, isNull);
    expect(xray.routing, isNull);
    expect(_outboundTags(xray), <String?>[RoutingOutboundTag.proxy.name]);
  });

  test('Global mode keeps the proxy dependency chain in order', () {
    final xray = _runtimeConfig();
    final proxy = _outbound(xray, RoutingOutboundTag.proxy.name);
    final chainProxy = _newOutbound(
      RoutingOutboundTag.chainProxy.name,
      protocol: 'vless',
    );
    final fragment = _newOutbound(
      RoutingOutboundTag.fragment.name,
      protocol: 'freedom',
    );
    _setDialerProxy(proxy, RoutingOutboundTag.chainProxy.name);
    _setDialerProxy(chainProxy, RoutingOutboundTag.fragment.name);
    xray.outbounds!.insertAll(0, <Map<String, dynamic>>[fragment, chainProxy]);

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.global),
      true,
    );

    expect(_outboundTags(xray), <String?>[
      RoutingOutboundTag.proxy.name,
      RoutingOutboundTag.chainProxy.name,
      RoutingOutboundTag.fragment.name,
    ]);
    expect(
      _dialerProxy(_outbound(xray, RoutingOutboundTag.proxy.name)),
      RoutingOutboundTag.chainProxy.name,
    );
    expect(
      _dialerProxy(_outbound(xray, RoutingOutboundTag.chainProxy.name)),
      RoutingOutboundTag.fragment.name,
    );
  });

  test('Global mode preserves App-unprojected siblings on deep copies', () {
    final xray = _runtimeConfig();
    final proxy = _outbound(xray, RoutingOutboundTag.proxy.name)
      ..addAll(<String, dynamic>{
        'settings': <String, dynamic>{
          'vnext': <dynamic>[],
          'appUnprojectedSetting': <String, dynamic>{'keep': true},
        },
        'streamSettings': <String, dynamic>{
          'network': 'xhttp',
          'security': 'reality',
          'xhttpSettings': <String, dynamic>{
            'path': '/keep',
            'appUnprojectedTransport': 1,
          },
          'realitySettings': <String, dynamic>{
            'serverName': 'example.com',
            'appUnprojectedSecurity': 2,
          },
          'sockopt': <String, dynamic>{'appUnprojectedSockopt': 3},
          'appUnprojectedStream': 4,
        },
        'mux': <String, dynamic>{'enabled': true, 'appUnprojectedMux': 5},
        'appUnprojectedRoot': 6,
      });
    final custom = _newOutbound('custom', protocol: 'socks')
      ..['appUnprojectedRoot'] = <String, dynamic>{'keep': true};
    _setDialerProxy(proxy, _tag(custom)!);
    xray.outbounds!.add(custom);
    final expectedProxy = _snapshotMap(proxy);
    final expectedCustom = _snapshotMap(custom);

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.global),
      true,
    );

    final fixedProxy = _outbound(xray, RoutingOutboundTag.proxy.name);
    final fixedCustom = _outbound(xray, _tag(custom)!);
    expect(fixedProxy, expectedProxy);
    expect(fixedCustom, expectedCustom);
    expect(identical(fixedProxy, proxy), false);
    expect(identical(fixedCustom, custom), false);
    expect(
      identical(fixedProxy['streamSettings'], proxy['streamSettings']),
      false,
    );
    expect(proxy, expectedProxy);
    expect(custom, expectedCustom);
  });

  test('Global mode rejects a missing proxy dependency atomically', () {
    final xray = _runtimeConfig();
    final proxy = _outbound(xray, RoutingOutboundTag.proxy.name);
    _setDialerProxy(proxy, 'missing');
    final original = _snapshot(xray.toJson());

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.global),
      false,
    );
    expect(xray.toJson(), original);
  });

  test('Global mode rejects a proxy dependency cycle atomically', () {
    final xray = _runtimeConfig();
    final proxy = _outbound(xray, RoutingOutboundTag.proxy.name);
    final custom = _newOutbound('custom', protocol: 'vless');
    _setDialerProxy(proxy, _tag(custom)!);
    _setDialerProxy(custom, _tag(proxy)!);
    xray.outbounds!.add(custom);
    final original = _snapshot(xray.toJson());

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.global),
      false,
    );
    expect(xray.toJson(), original);
  });

  test('Global mode rejects duplicate outbound tags atomically', () {
    final xray = _runtimeConfig()
      ..outbounds!.add(
        _newOutbound(RoutingOutboundTag.proxy.name, protocol: 'socks'),
      );
    final original = _snapshot(xray.toJson());

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.global),
      false,
    );
    expect(xray.toJson(), original);
  });

  test('Direct mode removes only dialerProxy from a deep copy', () {
    final xray = _runtimeConfig();
    final direct = _outbound(xray, RoutingOutboundTag.direct.name)
      ..addAll(<String, dynamic>{
        'settings': <String, dynamic>{
          'domainStrategy': 'UseIP',
          'appUnprojectedSetting': <String, dynamic>{'keep': true},
        },
        'streamSettings': <String, dynamic>{
          'network': 'xhttp',
          'security': 'tls',
          'xhttpSettings': <String, dynamic>{
            'path': '/keep',
            'appUnprojectedTransport': 1,
          },
          'tlsSettings': <String, dynamic>{
            'serverName': 'example.com',
            'appUnprojectedSecurity': 2,
          },
          'sockopt': <String, dynamic>{
            'dialerProxy': RoutingOutboundTag.fragment.name,
            'interface': 'en0',
            'appUnprojectedSockopt': 3,
          },
          'appUnprojectedStream': 4,
        },
        'mux': <String, dynamic>{'enabled': true, 'appUnprojectedMux': 5},
        'appUnprojectedRoot': 6,
      });
    final originalDirect = _snapshotMap(direct);
    final expectedDirect = _snapshotMap(direct);
    final expectedStreamSettings =
        expectedDirect['streamSettings']! as Map<String, dynamic>;
    final expectedSockopt =
        expectedStreamSettings['sockopt']! as Map<String, dynamic>;
    expectedSockopt.remove('dialerProxy');

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.direct),
      true,
    );

    final fixedDirect = _outbound(xray, RoutingOutboundTag.direct.name);
    expect(xray.dns, isNull);
    expect(xray.routing, isNull);
    expect(_outboundTags(xray), <String?>[RoutingOutboundTag.direct.name]);
    expect(fixedDirect, expectedDirect);
    expect(identical(fixedDirect, direct), false);
    expect(
      identical(fixedDirect['streamSettings'], direct['streamSettings']),
      false,
    );
    expect(direct, originalDirect);
    expect(_dialerProxy(direct), RoutingOutboundTag.fragment.name);
  });

  test('Global Raw JSON preserves App-unprojected siblings on copies', () {
    final proxy = _newOutbound(RoutingOutboundTag.proxy.name, protocol: 'vless')
      ..addAll(<String, dynamic>{
        'settings': <String, dynamic>{'appUnprojectedSetting': 1},
        'streamSettings': <String, dynamic>{
          'sockopt': <String, dynamic>{
            'dialerProxy': 'custom',
            'appUnprojectedSockopt': 2,
          },
          'appUnprojectedStream': 3,
        },
        'appUnprojectedRoot': 4,
      });
    final custom = _newOutbound('custom', protocol: 'socks')
      ..['appUnprojectedRoot'] = <String, dynamic>{'keep': true};
    final expectedProxy = _snapshotMap(proxy);
    final expectedCustom = _snapshotMap(custom);
    final raw = <String, dynamic>{
      'customRoot': <String, dynamic>{'keep': true},
      'dns': <String, dynamic>{
        'servers': <dynamic>['8.8.8.8'],
      },
      'routing': <String, dynamic>{'rules': <dynamic>[]},
      'inbounds': <dynamic>[
        <String, dynamic>{'tag': 'customIn', 'port': 1080},
      ],
      'outbounds': <dynamic>[
        _newOutbound(RoutingOutboundTag.direct.name, protocol: 'freedom'),
        proxy,
        custom,
        _newOutbound(RoutingOutboundTag.block.name, protocol: 'blackhole'),
      ],
    };

    expect(XrayRoutingModeFix.applyGlobalToRawJson(raw), true);

    expect(raw['customRoot'], <String, dynamic>{'keep': true});
    expect(raw.containsKey('dns'), false);
    expect(raw.containsKey('routing'), false);
    final fixedOutbounds = raw['outbounds']! as List<Map<String, dynamic>>;
    expect(fixedOutbounds.map(_tag), <String?>[
      RoutingOutboundTag.proxy.name,
      'custom',
    ]);
    final fixedProxy = _outboundFromList(
      fixedOutbounds,
      RoutingOutboundTag.proxy.name,
    );
    final fixedCustom = _outboundFromList(fixedOutbounds, 'custom');
    expect(fixedProxy, expectedProxy);
    expect(fixedCustom, expectedCustom);
    expect(identical(fixedProxy, proxy), false);
    expect(identical(fixedCustom, custom), false);
    expect(proxy, expectedProxy);
    expect(custom, expectedCustom);
    expect(
      ((raw['inbounds']! as List<dynamic>).single
          as Map<String, dynamic>)['port'],
      1080,
    );
  });

  test('Global mode reports a missing proxy outbound', () {
    final xray = _runtimeConfig()
      ..outbounds!.removeWhere(
        (outbound) => _tag(outbound) == RoutingOutboundTag.proxy.name,
      );

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.global),
      false,
    );
  });

  test('Direct mode reports a missing direct outbound', () {
    final xray = _runtimeConfig()
      ..outbounds!.removeWhere(
        (outbound) => _tag(outbound) == RoutingOutboundTag.direct.name,
      );

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.direct),
      false,
    );
  });
}

XrayJson _runtimeConfig() {
  final proxy = _newOutbound(RoutingOutboundTag.proxy.name, protocol: 'vless');
  final direct = _newOutbound(
    RoutingOutboundTag.direct.name,
    protocol: 'freedom',
  );
  final block = _newOutbound(
    RoutingOutboundTag.block.name,
    protocol: 'blackhole',
  );
  final dnsOut = _newOutbound(RoutingOutboundTag.dnsOut.name, protocol: 'dns');
  _setDialerProxy(dnsOut, RoutingOutboundTag.direct.name);
  final tunIn = XrayInboundStandard.standard
    ..protocol = 'tun'
    ..tag = RoutingInboundTag.tunIn.name;
  final pingIn = XrayInboundStandard.standard
    ..protocol = 'http'
    ..tag = RoutingInboundTag.pingIn.name;
  final rules = <XrayRoutingRule>[
    XrayRoutingRuleStandard.standard
      ..domain = <String>['geosite:private']
      ..outboundTag = RoutingOutboundTag.direct.name
      ..ruleTag = 'custom',
  ];
  return XrayJsonStandard.standard
    ..dns = XrayDnsStandard.standard
    ..inbounds = <XrayInbound>[tunIn, pingIn]
    ..outbounds = <Map<String, dynamic>>[proxy, direct, block, dnsOut]
    ..routing = (XrayRoutingStandard.standard..rules = rules);
}

Map<String, dynamic> _newOutbound(String tag, {required String protocol}) {
  return <String, dynamic>{'protocol': protocol, 'tag': tag};
}

Map<String, dynamic> _outbound(XrayJson xray, String tag) {
  return _outboundFromList(xray.outbounds!, tag);
}

Map<String, dynamic> _outboundFromList(
  List<Map<String, dynamic>> outbounds,
  String tag,
) {
  return outbounds.firstWhere((outbound) => _tag(outbound) == tag);
}

void _setDialerProxy(Map<String, dynamic> outbound, String tag) {
  final streamSettings =
      (outbound['streamSettings'] as Map<String, dynamic>?) ??
      <String, dynamic>{};
  final sockopt =
      (streamSettings['sockopt'] as Map<String, dynamic>?) ??
      <String, dynamic>{};
  sockopt['dialerProxy'] = tag;
  streamSettings['sockopt'] = sockopt;
  outbound['streamSettings'] = streamSettings;
}

List<String?> _outboundTags(XrayJson xray) {
  return xray.outbounds!.map(_tag).toList();
}

String? _tag(Map<String, dynamic> outbound) {
  final tag = outbound['tag'];
  return tag is String ? tag : null;
}

String? _dialerProxy(Map<String, dynamic> outbound) {
  final streamSettings = outbound['streamSettings'];
  if (streamSettings is! Map<String, dynamic>) {
    return null;
  }
  final sockopt = streamSettings['sockopt'];
  if (sockopt is! Map<String, dynamic>) {
    return null;
  }
  final dialerProxy = sockopt['dialerProxy'];
  return dialerProxy is String ? dialerProxy : null;
}

Map<String, dynamic> _snapshotMap(Map<String, dynamic> value) {
  return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}

dynamic _snapshot(Object? value) {
  return jsonDecode(jsonEncode(value));
}
