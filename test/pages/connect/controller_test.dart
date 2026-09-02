import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/ping_auth.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/controller.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  for (final fail in [false, true]) {
    testWidgets('leaving Raw follows the committed result; failure=$fail', (
      tester,
    ) async {
      final coordinator = _Coordinator(fail: fail);
      final controller =
          ConnectController(database: coordinator.db, coordinator: coordinator)
            ..expertView = true
            ..configuration = coordinator.saved;
      addTearDown(controller.dispose);
      addTearDown(coordinator.dispose);
      addTearDown(coordinator.db.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (_, child) => ShadTheme(
            data: AppTheme.shad(Brightness.light),
            child: ShadToaster(child: child!),
          ),
          home: const Scaffold(body: SizedBox()),
        ),
      );
      final context = tester.element(find.byType(Scaffold));
      final changing = controller.toggleExpert(context, false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply and reconnect'));
      await tester.pumpAndSettle();
      await changing;
      expect(controller.expertView, fail);
      expect(coordinator.saved.connection.expert, fail);
      if (!fail) {
        expect(controller.configuration.encode(), coordinator.saved.encode());
        expect(
          controller.configuration.connection.selection.kind,
          SelectionKind.automatic,
        );
        expect(coordinator.state.value.issue, 'selectionReset');
      }
    });
  }

  test('running path keeps all frozen names and is absent for Raw or stopped sessions', () async {
    final coordinator = _Coordinator();
    final controller = ConnectController(
      database: coordinator.db,
      coordinator: coordinator,
    );
    addTearDown(controller.dispose);
    addTearDown(coordinator.dispose);
    addTearDown(coordinator.db.close);
    final plan = _plan();
    coordinator.state.value = ConnectionView(
      phase: ConnectionPhase.connected,
      plan: plan,
    );
    controller.servers = [
      CoreConfigData(
        id: 1,
        name: 'Renamed after connection',
        type: 'outbound',
        tags: '',
        delay: 10,
        subId: 0,
        favorite: false,
      ),
    ];
    expect(controller.runningRoute, (
      entryCount: 2,
      path: 'Singapore 03 + Japan 02 → United States 01',
    ));
    coordinator.state.value = ConnectionView(
      phase: ConnectionPhase.disconnected,
      plan: plan,
    );
    expect(controller.runningRoute, isNull);
    coordinator.state.value = ConnectionView(
      phase: ConnectionPhase.connected,
      plan: _plan(expert: true),
    );
    expect(controller.runningRoute, isNull);
  });
}

/// Exercises the controller's result handling; native transaction/rollback
/// behavior is covered by service/connection/coordinator_test.dart.
class _Coordinator extends ConnectionCoordinator {
  _Coordinator({this.fail = false})
    : super(database: AppDatabase.forTesting(NativeDatabase.memory())) {
    state.value = const ConnectionView(phase: ConnectionPhase.connected);
  }
  final bool fail;
  ConnectionConfiguration saved = ConnectionConfiguration(
    connection: ConnectionSettings(
      expert: true,
      rawId: 9,
      selection: const ServerSelection.server(99),
    ),
  );

  @override
  Future<ConnectionConfiguration> get configuration async => saved;

  @override
  Future<void> apply(
    ConnectionConfiguration next, {
    bool connect = false,
    bool disconnect = false,
    bool affectsRuntime = true,
    bool allowReconnect = true,
    String? expectedConfiguration,
    Future<void> Function()? writeAssets,
    PrepareConnection? prepare,
  }) async {
    if (fail) {
      state.value = const ConnectionView(
        phase: ConnectionPhase.connected,
        issue: 'changeFailed',
      );
      throw StateError('Previous settings restored');
    }
    saved = ConnectionConfiguration(
      connection: ConnectionSettings.fromJson({
        ...next.connection.toJson(),
        'selection': const ServerSelection.automatic().toJson(),
      }),
      policy: next.policy,
    );
    state.value = const ConnectionView(
      phase: ConnectionPhase.connected,
      issue: 'selectionReset',
    );
  }
}

ConnectionPlan _plan({bool expert = false}) {
  const id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final configuration = ConnectionConfiguration(
    connection: ConnectionSettings(expert: expert),
  );
  ServerSnapshot server(int id, String name) => ServerSnapshot(
    id: id,
    sourceId: 0,
    outbound: {'protocol': 'freedom', 'tag': name},
  );
  final invoke = LibXrayInvokeRequest(
    method: LibXrayMethod.runXray,
    payload: RunXrayRequest(
      '{}',
      runtime: const ManagedRuntimeRequest(
        statePath: '/fixture/run/runtime.json',
        planId: id,
      ),
    ).toJson(),
  );
  return ConnectionPlan.create(
    id: id,
    configuration: configuration,
    compiled: CompiledConnection(
      xrayJson: '{}',
      settingsJson: jsonEncode(configuration.connection.toJson()),
      entries: [server(1, 'Singapore 03'), server(2, 'Japan 02')],
      finalExit: server(3, 'United States 01'),
      nodeTags: {},
      ruleTags: {},
      assetDirectory: '/fixture/assets',
    ),
    platform: ConnectionPlatform.android,
    request: StartVpnRequest(
      configuration.policy.toTun(ConnectionPlatform.android),
      null,
      '18002',
      XrayInboundAccount('fixture', 'fixture'),
      '18003',
      jsonEncode(invoke.toJson()),
    ),
  );
}
