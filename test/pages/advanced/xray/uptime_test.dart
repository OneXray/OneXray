import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/advanced/controller.dart';
import 'package:onexray/pages/advanced/tab_visibility.dart';
import 'package:onexray/service/connect/coordinator.dart';

import 'dart:convert';

import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connect/compiler.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';

void main() {
  testWidgets('visible inactive windows keep the uptime clock running', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final coordinator = ConnectionCoordinator(database: db);
    var now = DateTime(2026, 9, 3);
    coordinator.state.value = ConnectionView(
      phase: ConnectionPhase.connected,
      runtime: _runtime(now.subtract(const Duration(minutes: 1))),
    );
    final controller = _AdvancedController(
      coordinator: coordinator,
      now: () => now,
    );
    try {
      controller.setVisible(true);
      await tester.pump();
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.state.uptime, '0:01:01');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.state.uptime, '0:01:02');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      expect(controller.state.uptime, '0:01:02');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(controller.state.uptime, '0:01:07');
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.state.uptime, '0:01:08');
    } finally {
      await controller.close();
      coordinator.dispose();
      await db.close();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });

  testWidgets(
    'uptime uses a visible application clock, without metrics updates',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final coordinator = ConnectionCoordinator(database: db);
      var now = DateTime(2026, 9, 3);
      coordinator.state.value = ConnectionView(
        phase: ConnectionPhase.connected,
        runtime: _runtime(now.subtract(const Duration(minutes: 1))),
      );
      final controller = _AdvancedController(
        coordinator: coordinator,
        now: () => now,
      );
      controller.setVisible(true);
      await tester.pump();
      expect(controller.state.uptime, '0:01:00');
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.state.uptime, '0:01:01');

      controller.setVisible(false);
      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(controller.state.uptime, '0:01:01');
      controller.setVisible(true);
      expect(controller.state.uptime, '0:01:04');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      expect(controller.state.uptime, '0:01:04');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(controller.state.uptime, '0:01:09');

      coordinator.state.value = const ConnectionView();
      expect(controller.state.uptime, '—');
      await controller.close();
      coordinator.dispose();
      await db.close();
    },
  );

  testWidgets('xray uptime stops after switching to the tunnel tab', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final coordinator = ConnectionCoordinator(database: db);
    var now = DateTime(2026, 9, 3);
    coordinator.state.value = ConnectionView(
      phase: ConnectionPhase.connected,
      runtime: _runtime(now.subtract(const Duration(minutes: 1))),
    );
    final controller = _AdvancedController(
      coordinator: coordinator,
      now: () => now,
    );
    late BuildContext tabsContext;
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 2,
          initialIndex: 1,
          child: Builder(
            builder: (context) {
              tabsContext = context;
              return AdvancedTabVisibility(
                tabIndex: 1,
                onChanged: controller.setVisible,
                child: const SizedBox(),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.state.uptime, '0:01:00');

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.state.uptime, '0:01:01');

    DefaultTabController.of(tabsContext).animateTo(0, duration: Duration.zero);
    await tester.pump();
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(controller.state.uptime, '0:01:01');

    await tester.pumpWidget(const SizedBox());
    await controller.close();
    coordinator.dispose();
    await db.close();
  });
}

class _AdvancedController extends AdvancedController {
  _AdvancedController({required super.coordinator, required super.now});

  @override
  Future<void> reload() async {}
}

ConnectionRuntime _runtime(DateTime startedAt) => ConnectionRuntime.create(
  configuration: ConnectionConfiguration(),
  compiled: CompiledConnection(
    xrayJson: '{}',
    validationJson: '{}',
    entries: const [],
    finalExit: null,
    nodeTags: const {},
  ),
  platform: ConnectionPlatform.android,
  request: StartVpnRequest(
    null,
    null,
    '18003',
    jsonEncode(
      LibXrayInvokeRequest(
        method: LibXrayMethod.runXray,
        payload: RunXrayRequest('{}').toJson(),
      ).toJson(),
    ),
  ),
  startedAt: startedAt,
);
