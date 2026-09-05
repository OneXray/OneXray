import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'connection failure notifications stay at shortcut and tray entries',
    () {
      final shortcut = File('lib/service/menu/short_cut/service.dart')
          .readAsStringSync();
      final tray = File('lib/service/menu/tray/service.dart')
          .readAsStringSync();
      final connect = File('lib/pages/connect/controller.dart')
          .readAsStringSync();

      for (final source in [shortcut, tray]) {
        expect(source, contains('NotificationService().pushNotification('));
        expect(source, contains('prototypeConnectionFailed'));
      }
      expect(connect, isNot(contains('NotificationService')));
    },
  );

  test('Darwin notification permission is not requested during startup', () {
    final source = File('lib/service/notification/service.dart')
        .readAsStringSync();

    expect(source, contains('requestAlertPermission: false'));
    expect(source, contains('requestSoundPermission: false'));
    expect(source, contains('requestBadgePermission: false'));
    expect(source, contains('requestPermissions(alert: true)'));
  });
}
