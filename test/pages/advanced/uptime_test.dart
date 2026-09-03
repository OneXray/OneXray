import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/advanced/controller.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/traffic_accounting.dart';

void main() {
  testWidgets(
    'uptime uses a visible foreground clock, without metrics updates',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final coordinator = ConnectionCoordinator(database: db);
      var now = DateTime(2026, 9, 3);
      coordinator.state.value = ConnectionView(
        phase: ConnectionPhase.connected,
        traffic: RuntimeSnapshot(
          sessionId: 'session',
          planId: 'plan',
          startedAtMs: now.millisecondsSinceEpoch - 60000,
          endedAtMs: 0,
          uplink: 0,
          downlink: 0,
          available: true,
          sampledAtMs: now.millisecondsSinceEpoch,
          savedAtMs: now.millisecondsSinceEpoch,
          error: '',
        ),
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
}

class _AdvancedController extends AdvancedController {
  _AdvancedController({required super.coordinator, required super.now});

  @override
  Future<void> reload() async {}
}
