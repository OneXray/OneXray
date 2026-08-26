import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/core_routing_mode.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/routing_mode.dart';

void main() {
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

  test('Map global mode keeps every outbound', () {
    final proxy = _newOutbound(
      RoutingOutboundTag.proxy.name,
      protocol: 'vless',
    );
    _setDialerProxy(proxy, 'custom');
    final originalProxy = _snapshotMap(proxy);
    final raw = <String, dynamic>{
      'dns': <String, dynamic>{},
      'routing': <String, dynamic>{},
      'outbounds': <dynamic>[
        _newOutbound(RoutingOutboundTag.direct.name, protocol: 'freedom'),
        proxy,
        _newOutbound(RoutingOutboundTag.block.name, protocol: 'blackhole'),
        _newOutbound('custom', protocol: 'socks'),
      ],
    };

    expect(
      XrayRoutingModeFix.applyToRawJson(raw, CoreRoutingMode.global),
      true,
    );

    final outbounds = raw['outbounds']! as List<Map<String, dynamic>>;
    expect(outbounds.map(_tag), <String?>[
      RoutingOutboundTag.proxy.name,
      RoutingOutboundTag.direct.name,
      RoutingOutboundTag.block.name,
      'custom',
    ]);
    expect(raw.containsKey('dns'), false);
    expect(raw.containsKey('routing'), false);
    expect(proxy, originalProxy);
    expect(identical(outbounds.first, proxy), false);
  });

  test('Map direct mode clears only the direct chain', () {
    final direct = _newOutbound(
      RoutingOutboundTag.direct.name,
      protocol: 'freedom',
    );
    _setDialerProxy(direct, RoutingOutboundTag.fragment.name);
    _setProxyTag(direct, RoutingOutboundTag.fragment.name);
    final raw = <String, dynamic>{
      'name': 'Profile  name',
      'observatory': <String, dynamic>{'future': ' keep  spaces '},
      'version': <String, dynamic>{'min': '1.0'},
      'outbounds': <dynamic>[
        _newOutbound(RoutingOutboundTag.proxy.name, protocol: 'vless'),
        direct,
        _newOutbound(RoutingOutboundTag.block.name, protocol: 'blackhole')
          ..['future'] = <String, dynamic>{'keep': true},
      ],
    };

    expect(
      XrayRoutingModeFix.applyToRawJson(raw, CoreRoutingMode.direct),
      true,
    );

    final outbounds = raw['outbounds']! as List<Map<String, dynamic>>;
    expect(outbounds.map(_tag), <String?>[
      RoutingOutboundTag.direct.name,
      RoutingOutboundTag.proxy.name,
      RoutingOutboundTag.block.name,
    ]);
    expect(_dialerProxy(outbounds.first), isNull);
    expect(_proxyTag(outbounds.first), isNull);
    expect(_dialerProxy(direct), RoutingOutboundTag.fragment.name);
    expect(_proxyTag(direct), RoutingOutboundTag.fragment.name);
    expect(raw['name'], 'Profile  name');
    expect(raw['observatory'], <String, dynamic>{'future': ' keep  spaces '});
    expect(raw['version'], <String, dynamic>{'min': '1.0'});
    expect(outbounds.last['future'], <String, dynamic>{'keep': true});
  });

  test('Multi-node Outbound rejects a missing proxySettings dependency', () {
    final proxy = _newOutbound(
      RoutingOutboundTag.proxy.name,
      protocol: 'vless',
    );
    _setProxyTag(proxy, 'missing');
    final raw = <String, dynamic>{
      'outbounds': <dynamic>[
        proxy,
        _newOutbound(RoutingOutboundTag.direct.name, protocol: 'freedom'),
      ],
    };
    final original = _snapshot(raw);

    expect(
      XrayRoutingModeFix.applyToRawJson(raw, CoreRoutingMode.global),
      false,
    );
    expect(raw, original);
  });

  test('Multi-node Outbound rejects conflicting dependency mechanisms', () {
    final proxy = _newOutbound(
      RoutingOutboundTag.proxy.name,
      protocol: 'vless',
    );
    _setDialerProxy(proxy, 'chain');
    _setProxyTag(proxy, 'chain');
    final raw = <String, dynamic>{
      'outbounds': <dynamic>[proxy, _newOutbound('chain', protocol: 'socks')],
    };
    final original = _snapshot(raw);

    expect(
      XrayRoutingModeFix.applyToRawJson(raw, CoreRoutingMode.global),
      false,
    );
    expect(raw, original);
  });

  test('Multi-node Outbound routing modes reject duplicate tags', () {
    final raw = <String, dynamic>{
      'outbounds': <dynamic>[
        _newOutbound(RoutingOutboundTag.proxy.name, protocol: 'vless'),
        _newOutbound(RoutingOutboundTag.proxy.name, protocol: 'vless'),
      ],
    };

    expect(
      XrayRoutingModeFix.applyToRawJson(raw, CoreRoutingMode.global),
      false,
    );
  });
}

Map<String, dynamic> _newOutbound(String tag, {required String protocol}) {
  return <String, dynamic>{'protocol': protocol, 'tag': tag};
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

void _setProxyTag(Map<String, dynamic> outbound, String tag) {
  outbound['proxySettings'] = <String, dynamic>{
    'tag': tag,
    'transportLayer': true,
  };
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

String? _proxyTag(Map<String, dynamic> outbound) {
  final proxySettings = outbound['proxySettings'];
  if (proxySettings is! Map<String, dynamic>) {
    return null;
  }
  final tag = proxySettings['tag'];
  return tag is String ? tag : null;
}

Map<String, dynamic> _snapshotMap(Map<String, dynamic> value) {
  return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}

dynamic _snapshot(Object? value) {
  return jsonDecode(jsonEncode(value));
}
