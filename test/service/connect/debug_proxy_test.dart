import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connect/compiler.dart';
import 'package:onexray/service/connect/debug_proxy.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test(
    'only the managed TUN inbound changes; other invocation fields survive',
    () {
      final runtime = _runtime();
      final original = jsonEncode(runtime.request.toJson());
      final before = LibXrayRunConfig.fromInvokeText(
        runtime.request.coreInvokeText!,
      );
      final after = LibXrayRunConfig.fromInvokeText(
        IOSDebugProxy.buildInvoke(runtime),
      );
      final source =
          jsonDecode(before.request.xrayJson!) as Map<String, dynamic>;
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
      expect(jsonEncode(runtime.request.toJson()), original);
    },
  );

  test('conversion rejects missing, invalid, or occupied metrics ports', () {
    for (final port in [null, '', '0', '65536', 'invalid', '18003']) {
      expect(
        () => IOSDebugProxy.buildInvoke(_runtime(port: port)),
        throwsFormatException,
      );
    }
    expect(
      () => IOSDebugProxy.buildInvoke(_runtime(platform: 'macos')),
      throwsFormatException,
    );
    expect(
      () => IOSDebugProxy.buildInvoke(_runtime(withTun: false)),
      throwsFormatException,
    );
  });

  group('Debug start request persistence', () {
    const directoryChannel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.onexray.BridgeHostApi.getTunFilesDir',
      BridgeHostApi.pigeonChannelCodec,
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late Directory directory;

    setUp(() async {
      final fixtures = await Directory('../references/onexray-tests').absolute
          .create(recursive: true);
      directory = await fixtures.createTemp('debug-proxy-start-');
      addTearDown(() async {
        messenger.setMockDecodedMessageHandler(directoryChannel, null);
        await directory.delete(recursive: true);
      });
      messenger.setMockDecodedMessageHandler(directoryChannel, (_) async {
        return [directory.path];
      });
      await AppHostApi().initTunFilesDir();
    });

    for (final existing in [false, true]) {
      test(
        'persists the exact Debug invocation (existing: $existing)',
        () async {
          final runtime = _runtime();
          final original = runtime.request.toJson();
          final start = File(VpnConstants.startPath);
          if (existing) {
            await start.parent.create(recursive: true);
            await start.writeAsString(jsonEncode(original));
          }

          final invoke = await IOSDebugProxy.prepareInvoke(runtime);

          expect(await start.exists(), isTrue);
          final saved = StartVpnRequest.fromJson(
            jsonDecode(await start.readAsString()) as Map<String, dynamic>,
          );
          expect(saved.coreInvokeText, invoke);
          expect(saved.toJson(), {...original, 'coreInvokeText': invoke});
          final xray = LibXrayRunConfig.fromInvokeText(invoke)
              .request
              .xrayJson!;
          expect(jsonDecode(xray)['inbounds'][0]['protocol'], 'socks');
          expect(runtime.request.toJson(), original);
          expect(
            jsonDecode(runtime.xrayJson)['inbounds'][0]['protocol'],
            'tun',
          );
          expect(await File('${start.path}.tmp').exists(), isFalse);
        },
      );
    }

    test('propagates a write failure before starting the core', () async {
      await File(VpnConstants.runDir).writeAsString('not a directory');
      await expectLater(
        IOSDebugProxy.prepareInvoke(_runtime()),
        throwsA(isA<FileSystemException>()),
      );
    });
  }, skip: Platform.isLinux || Platform.isWindows);
}

ConnectionRuntime _runtime({
  String? port = '18001',
  String platform = 'ios',
  bool withTun = true,
}) {
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
    'log': {'access': '/fixture/run/access.log'},
  });
  final invoke = LibXrayInvokeRequest(
    method: LibXrayMethod.runXray,
    payload: RunXrayRequest(config).toJson(),
  );
  final configuration = ConnectionConfiguration();
  return ConnectionRuntime.create(
    configuration: configuration,
    compiled: CompiledConnection(
      xrayJson: config,
      entries: const [],
      finalExit: null,
      nodeTags: const {},
    ),
    platform: ConnectionPlatform.values.byName(platform),
    request: StartVpnRequest(null, port, '18003', jsonEncode(invoke.toJson())),
  );
}
