import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/model/xray_standard.dart';
import 'package:onexray/service/core_routing_mode/state.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/routing_mode.dart';

void main() {
  test('Rule mode leaves the final config unchanged', () {
    final xray = _runtimeConfig();
    final original = xray.toJson();

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.rule),
      true,
    );

    expect(xray.toJson(), original);
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
    xray.outbounds!.insertAll(0, <XrayOutbound>[fragment, chainProxy]);

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.global),
      true,
    );

    expect(_outboundTags(xray), <String?>[
      RoutingOutboundTag.proxy.name,
      RoutingOutboundTag.chainProxy.name,
      RoutingOutboundTag.fragment.name,
    ]);
    expect(_dialerProxy(proxy), RoutingOutboundTag.chainProxy.name);
    expect(_dialerProxy(chainProxy), RoutingOutboundTag.fragment.name);
  });

  test('Global mode keeps custom proxy dependencies in order', () {
    final xray = _runtimeConfig();
    final proxy = _outbound(xray, RoutingOutboundTag.proxy.name);
    final custom1 = _newOutbound('custom1', protocol: 'vless');
    final custom2 = _newOutbound('custom2', protocol: 'socks');
    _setDialerProxy(proxy, custom1.tag!);
    _setDialerProxy(custom1, custom2.tag!);
    xray.outbounds!.addAll(<XrayOutbound>[custom2, custom1]);

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.global),
      true,
    );

    expect(_outboundTags(xray), <String?>[
      RoutingOutboundTag.proxy.name,
      custom1.tag,
      custom2.tag,
    ]);
    expect(_dialerProxy(proxy), custom1.tag);
    expect(_dialerProxy(custom1), custom2.tag);
  });

  test('Global mode rejects a missing proxy dependency', () {
    final xray = _runtimeConfig();
    final proxy = _outbound(xray, RoutingOutboundTag.proxy.name);
    _setDialerProxy(proxy, 'missing');

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.global),
      false,
    );
    expect(xray.dns, isNotNull);
    expect(xray.routing, isNotNull);
  });

  test('Global mode rejects a proxy dependency cycle', () {
    final xray = _runtimeConfig();
    final proxy = _outbound(xray, RoutingOutboundTag.proxy.name);
    final custom = _newOutbound('custom', protocol: 'vless');
    _setDialerProxy(proxy, custom.tag!);
    _setDialerProxy(custom, proxy.tag!);
    xray.outbounds!.add(custom);

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.global),
      false,
    );
  });

  test('Direct mode removes DNS and routing and keeps only direct', () {
    final xray = _runtimeConfig();
    final direct = _outbound(xray, RoutingOutboundTag.direct.name);
    _setDialerProxy(direct, RoutingOutboundTag.fragment.name);

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.direct),
      true,
    );

    expect(xray.dns, isNull);
    expect(xray.routing, isNull);
    expect(_outboundTags(xray), <String?>[RoutingOutboundTag.direct.name]);
    expect(_dialerProxy(direct), isNull);
  });

  test('Global Raw JSON keeps unknown fields on retained outbounds', () {
    final xray = _runtimeConfig();
    final proxy = _outbound(xray, RoutingOutboundTag.proxy.name);
    final custom = _newOutbound('custom', protocol: 'vless');
    final fragment = _newOutbound(
      RoutingOutboundTag.fragment.name,
      protocol: 'freedom',
    );
    _setDialerProxy(proxy, custom.tag!);
    _setDialerProxy(custom, RoutingOutboundTag.fragment.name);
    xray.outbounds!.addAll(<XrayOutbound>[custom, fragment]);

    final raw = xray.toJson()
      ..['customRoot'] = <String, dynamic>{'keep': true}
      ..['dns'] = <String, dynamic>{
        'servers': <dynamic>['8.8.8.8'],
      }
      ..['inbounds'] = <dynamic>[
        <String, dynamic>{
          'tag': 'customIn',
          'protocol': 'dokodemo-door',
          'port': 1080,
        },
      ];
    final rawOutbounds = raw['outbounds']! as List<dynamic>;
    final rawProxy = _rawOutbound(rawOutbounds, RoutingOutboundTag.proxy.name)
      ..['customOutboundField'] = 'keep';
    raw['outbounds'] = <dynamic>[
      _rawOutbound(rawOutbounds, RoutingOutboundTag.direct.name),
      fragment.toJson(),
      rawProxy,
      custom.toJson(),
      _rawOutbound(rawOutbounds, RoutingOutboundTag.block.name),
    ];

    expect(XrayRoutingModeFix.applyGlobalToRawJson(raw), true);

    expect(raw['customRoot'], <String, dynamic>{'keep': true});
    expect(raw.containsKey('dns'), false);
    expect(raw.containsKey('routing'), false);
    final fixedOutbounds = raw['outbounds']! as List<dynamic>;
    expect(
      fixedOutbounds.whereType<Map>().map((outbound) => outbound['tag']),
      <String>[
        RoutingOutboundTag.proxy.name,
        custom.tag!,
        RoutingOutboundTag.fragment.name,
      ],
    );
    expect(
      _rawOutbound(
        fixedOutbounds,
        RoutingOutboundTag.proxy.name,
      )['customOutboundField'],
      'keep',
    );
    expect(((raw['inbounds']! as List<dynamic>).single as Map)['port'], 1080);
  });

  test('Global mode reports a missing proxy outbound', () {
    final xray = _runtimeConfig()
      ..outbounds!.removeWhere(
        (outbound) => outbound.tag == RoutingOutboundTag.proxy.name,
      );

    expect(
      XrayRoutingModeFix.applyToXrayJson(xray, CoreRoutingMode.global),
      false,
    );
  });

  test('Direct mode reports a missing direct outbound', () {
    final xray = _runtimeConfig()
      ..outbounds!.removeWhere(
        (outbound) => outbound.tag == RoutingOutboundTag.direct.name,
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
    ..outbounds = <XrayOutbound>[proxy, direct, block, dnsOut]
    ..routing = (XrayRoutingStandard.standard..rules = rules);
}

XrayOutbound _newOutbound(String tag, {required String protocol}) {
  return XrayOutboundStandard.standard
    ..protocol = protocol
    ..tag = tag;
}

XrayOutbound _outbound(XrayJson xray, String tag) {
  return xray.outbounds!.firstWhere((outbound) => outbound.tag == tag);
}

Map _rawOutbound(List<dynamic> outbounds, String tag) {
  return outbounds.whereType<Map>().firstWhere(
    (outbound) => outbound['tag'] == tag,
  );
}

void _setDialerProxy(XrayOutbound outbound, String tag) {
  final streamSettings =
      outbound.streamSettings ?? XrayStreamSettingsStandard.standard;
  final sockopt = streamSettings.sockopt ?? XraySockoptStandard.standard;
  sockopt.dialerProxy = tag;
  streamSettings.sockopt = sockopt;
  outbound.streamSettings = streamSettings;
}

List<String?> _outboundTags(XrayJson xray) {
  return xray.outbounds!.map((outbound) => outbound.tag).toList();
}

String? _dialerProxy(XrayOutbound outbound) {
  return outbound.streamSettings?.sockopt?.dialerProxy;
}
