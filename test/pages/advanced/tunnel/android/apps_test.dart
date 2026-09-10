import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/pages/advanced/tunnel/android/apps.dart';

void main() {
  test(
    'failed app lookup keeps the native reason and clears it after retry',
    () async {
      final error = StateError('Package manager unavailable');
      var fail = true;
      final controller = AndroidAppsController(
        [],
        loadApps: () async {
          if (fail) throw error;
          return [];
        },
      );
      addTearDown(controller.close);
      await controller.load();
      expect(controller.state.failed, isTrue);
      expect(controller.state.failure, same(error));
      fail = false;
      await controller.load();
      expect(controller.state.failed, isFalse);
      expect(controller.state.failure, isNull);
    },
  );

  test('app picker searches names and package IDs without losing missing selections', () async {
    final controller = AndroidAppsController(
      ['com.example.uninstalled'],
      loadApps: () async => [
        AndroidAppInfo(name: 'Browser', packageName: 'org.example.browser'),
        AndroidAppInfo(name: 'Mail', packageName: 'org.example.mail'),
      ],
    );
    addTearDown(controller.close);
    await controller.load();
    expect(controller.missing, ['com.example.uninstalled']);
    controller.search('  BROW  ');
    expect(controller.visible.single.name, 'Browser');
    controller.search('org.example.mail');
    expect(controller.visible.single.name, 'Mail');
    controller.toggle('org.example.mail');
    expect(controller.selected, {
      'com.example.uninstalled',
      'org.example.mail',
    });
    controller.search('uninstalled');
    controller.toggle('com.example.uninstalled');
    expect(controller.missing, isEmpty);
    expect(controller.selected, {'org.example.mail'});
  });
}
