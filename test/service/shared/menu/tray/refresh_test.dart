import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/menu/tray/service.dart';

Iterable<Map<dynamic, dynamic>> _items(Map<dynamic, dynamic> menu) sync* {
  for (final item in menu['items'] as List) {
    yield item as Map<dynamic, dynamic>;
    final submenu = item['submenu'];
    if (submenu != null) yield* _items(submenu as Map<dynamic, dynamic>);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tray_manager');
  late AppDatabase db;
  late TrayService tray;
  late Completer<void> popupClosed;
  Completer<void>? iconReady;
  final menus = <Map<dynamic, dynamic>>[];
  final choices = <Map<String, dynamic>>[];
  var popups = 0;
  var connections = 0;

  Future<void> click(int id) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onTrayMenuItemClick', {'id': id}),
      ),
      (_) {},
    );
    await pumpEventQueue();
  }

  setUp(() async {
    menus.clear();
    choices.clear();
    popups = 0;
    connections = 0;
    iconReady = null;
    popupClosed = Completer<void>();
    final bus = AppEventBus();
    addTearDown(bus.close);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final coordinator = ConnectionCoordinator(
      database: db,
      disposeStatus: () {},
    );
    addTearDown(coordinator.dispose);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      switch (call.method) {
        case 'setIcon':
          await iconReady?.future;
        case 'setContextMenu':
          menus.add(call.arguments['menu'] as Map<dynamic, dynamic>);
        case 'popUpContextMenu':
          popups++;
          // AppKit/Win32's menu tracking call returns when the popup closes.
          await popupClosed.future;
      }
      return null;
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    tray =
        TrayService.forTesting(
            database: db,
            coordinator: coordinator,
            connect: () async => connections++,
            notify: (_) async => fail('No notification is expected'),
            showMainWindow: () async => fail('No window is needed'),
          )
          ..onConfigurationChange = (values, _, validate) async {
            await validate();
            choices.add(values);
          };
    addTearDown(() async {
      tray.dispose();
      if (iconReady != null && !iconReady!.isCompleted) iconReady!.complete();
      if (!popupClosed.isCompleted) popupClosed.complete();
      await pumpEventQueue();
    });
    tray.init();
    await pumpEventQueue();
    await tray.refreshTrayManager();
  });

  for (final rightClick in [false, true]) {
    test(
      'open menu survives background refresh (right click: $rightClick)',
      () async {
        final sourceId = await db.subscriptionDao.insertRow(
          SubscriptionCompanion.insert(
            name: 'Provider',
            url: 'https://example.com/sub',
            timestamp: DateTime(2026),
          ),
        );
        await pumpEventQueue();
        final oldMenu = menus.last;
        final published = menus.length;
        final start = _items(oldMenu)
            .singleWhere((item) => item['key'] == 'startVpn');
        final automatic = _items(oldMenu)
            .singleWhere((item) => item['key'] == 'automatic');
        if (rightClick) {
          tray.onTrayIconRightMouseDown();
        } else {
          tray.onTrayIconMouseDown();
        }
        await pumpEventQueue();
        expect(popups, 1);

        final source = (await db.subscriptionDao.searchRow(sourceId))!;
        await db.subscriptionDao.updateRow(
          source.copyWith(name: 'Renamed provider'),
        );
        await pumpEventQueue();
        await tray.refreshTrayManager();
        await tray.refreshTrayManager();
        expect(menus.length, published);
        await click(start['id'] as int);
        await click(automatic['id'] as int);
        expect(connections, 1);
        expect(choices, hasLength(1));
        expect(menus.length, published);

        popupClosed.complete();
        await pumpEventQueue();
        expect(menus.length, published + 1);
        expect(
          _items(
            menus.last,
          ).singleWhere((item) => item['key'] == 'source:$sourceId')['label'],
          'Renamed provider',
        );
        final newStart = _items(menus.last)
            .singleWhere((item) => item['key'] == 'startVpn');
        await click(newStart['id'] as int);
        expect(connections, 2);
      },
    );
  }

  test(
    'opening waits for an in-flight publish and queues later refreshes',
    () async {
      iconReady = Completer<void>();
      final refresh = tray.refreshTrayManager();
      tray.onTrayIconMouseDown();
      await pumpEventQueue();
      expect(popups, 0);
      await tray.refreshTrayManager();
      iconReady!.complete();
      await refresh;
      await pumpEventQueue();
      expect(popups, 1);
      final published = menus.length;
      await tray.refreshTrayManager();
      expect(menus.length, published);
      popupClosed.complete();
      await pumpEventQueue();
      expect(menus.length, published + 1);
    },
  );

  test('popup failure releases queued refreshes', () async {
    tray.onTrayIconMouseDown();
    await pumpEventQueue();
    final published = menus.length;
    await tray.refreshTrayManager();
    popupClosed.completeError(PlatformException(code: 'popup-failed'));
    await pumpEventQueue();
    expect(menus.length, published + 1);
    await tray.refreshTrayManager();
    expect(menus.length, published + 2);
  });
}
