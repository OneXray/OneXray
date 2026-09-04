import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connection/debug_proxy.dart';
import 'package:onexray/service/connection/plan.dart';

void main() {
  test('local proxy support requires both iOS and a debug build', () {
    for (final debug in [false, true]) {
      for (final ios in [false, true]) {
        expect(
          IOSDebugProxy.supportsEnvironment(debugMode: debug, isIOS: ios),
          debug && ios,
        );
      }
    }
  });

  test('only the managed TUN inbound changes; invocation and plan survive', () {
    final plan = _plan();
    final original = plan.encode();
    final before = LibXrayRunConfig.fromInvokeText(
      plan.request.coreInvokeText!,
    );
    final after = LibXrayRunConfig.fromInvokeText(
      IOSDebugProxy.buildInvoke(plan),
    );
    final source = jsonDecode(before.request.xrayJson!) as Map<String, dynamic>;
    final converted =
        jsonDecode(after.request.xrayJson!) as Map<String, dynamic>;
    final inbounds = converted['inbounds'] as List;

    expect(inbounds[0], containsPair('protocol', 'socks'));
    expect(inbounds[0], containsPair('listen', '127.0.0.1'));
    expect(inbounds[0], containsPair('port', '18001'));
    expect(inbounds[0], containsPair('tag', 'tunIn'));
    expect(inbounds.skip(1), (source['inbounds'] as List).skip(1));
    converted.remove('inbounds');
    source.remove('inbounds');
    expect(converted, source);
    expect(after.invoke.apiVersion, before.invoke.apiVersion);
    expect(after.invoke.method, before.invoke.method);
    expect(after.request.runtime!.toJson(), before.request.runtime!.toJson());
    expect(plan.encode(), original);
  });

  test('conversion rejects missing, invalid, or occupied metrics ports', () {
    for (final port in [null, '', '0', '65536', 'invalid', '18003']) {
      expect(
        () => IOSDebugProxy.buildInvoke(_plan(port: port)),
        throwsFormatException,
      );
    }
    expect(
      () => IOSDebugProxy.buildInvoke(_plan(platform: 'macos')),
      throwsFormatException,
    );
    expect(
      () => IOSDebugProxy.buildInvoke(_plan(withTun: false)),
      throwsFormatException,
    );
  });
}

ConnectionPlan _plan({
  String? port = '18001',
  String platform = 'ios',
  bool withTun = true,
}) {
  const id = 'ffffffffffffffffffffffffffffffff';
  final config = jsonEncode({
    'inbounds': [
      if (withTun)
        {
          'tag': 'tunIn',
          'protocol': 'tun',
          'settings': {'name': 'OneXrayTun'},
        },
      {'tag': 'rawInbound', 'protocol': 'http', 'port': 18004},
    ],
    'metrics': {'listen': '127.0.0.1:18003'},
    'stats': {},
    'dns': {
      'servers': ['8.8.8.8'],
    },
    'outbounds': [
      {'protocol': 'freedom', 'tag': 'direct'},
    ],
    'routing': {
      'rules': [
        {
          'type': 'field',
          'inboundTag': ['tunIn'],
          'outboundTag': 'direct',
        },
      ],
    },
    'log': {'access': '/fixture/run/plans/$id/access.log'},
  });
  final invoke = LibXrayInvokeRequest(
    method: LibXrayMethod.runXray,
    payload: RunXrayRequest(
      config,
      runtime: const ManagedRuntimeRequest(
        statePath: '/fixture/run/runtime.json',
        planId: id,
      ),
    ).toJson(),
  );
  return ConnectionPlan.decode(
    jsonEncode({
      'version': 1,
      'id': id,
      'platform': platform,
      'configuration': ConnectionConfiguration().toJson(),
      'request': StartVpnRequest(
        null,
        port,
        '18003',
        jsonEncode(invoke.toJson()),
      ).toJson(),
      'xrayJson': config,
      'entries': [],
      'nodeTags': {},
      'ruleTags': {},
      'assetDirectory': '/fixture/run/plans/$id/dat',
    }),
  );
}
