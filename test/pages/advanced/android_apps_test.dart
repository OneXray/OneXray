import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/pages/advanced/tunnel/apps.dart';

void main() {
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
