import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations_en.dart';
import 'package:onexray/service/shared/menu/short_cut/service.dart';

void main() {
  test('mobile publishes exactly the four agreed actions', () {
    final items = ShortCutService.items(AppLocalizationsEn());
    expect(items.map((item) => item.type), [
      'startVpn',
      'stopVpn',
      'chooseConfiguration',
      'updateSubscriptions',
    ]);
    expect(items.map((item) => item.localizedTitle), [
      'Start VPN',
      'Stop VPN',
      'Switch configuration',
      'Update subscriptions',
    ]);
    expect(items.map((item) => item.icon), [
      'start_vpn',
      'stop_vpn',
      'choose_configuration',
      'update_subscriptions',
    ]);
    for (final item in items) {
      final icon = item.icon!;
      expect(
        File('android/app/src/main/res/drawable/$icon.xml').existsSync(),
        isTrue,
      );
      final imageset = 'ios/Runner/Assets.xcassets/$icon.imageset';
      final asset = jsonDecode(
        File('$imageset/Contents.json').readAsStringSync(),
      );
      expect(asset['properties']['template-rendering-intent'], 'template');
      expect(File('$imageset/$icon.svg').existsSync(), isTrue);
    }
  });

  test(
    'cold launch waits for the shell and suppresses automatic connection',
    () async {
      var suppressed = 0;
      final service = ShortCutService.forTesting(
        suppressAutoConnect: () => suppressed++,
      );
      final actions = <ShortCutAction>[];
      await service.receive('stopVpn');
      expect(actions, isEmpty);
      expect(suppressed, 1);
      service.attach((action) async => actions.add(action));
      await pumpEventQueue();
      expect(actions, [ShortCutAction.stopVpn]);
      service.detach();
      service.attach((action) async => actions.add(action));
      await pumpEventQueue();
      expect(actions, hasLength(1));
    },
  );

  test(
    'warm calls ignore unknown and duplicate actions, but Stop is not blocked',
    () async {
      final service = ShortCutService.forTesting(
        suppressAutoConnect: () => fail('Already ready'),
      );
      final release = Completer<void>();
      final actions = <ShortCutAction>[];
      service.attach((action) async {
        actions.add(action);
        if (action == ShortCutAction.startVpn) await release.future;
      });
      await service.receive('unrecognized');
      final starting = service.receive('startVpn');
      await service.receive('startVpn');
      await service.receive('stopVpn');
      expect(actions, [ShortCutAction.startVpn, ShortCutAction.stopVpn]);
      release.complete();
      await starting;
      await service.receive('chooseConfiguration');
      expect(actions.last, ShortCutAction.chooseConfiguration);
    },
  );
}
