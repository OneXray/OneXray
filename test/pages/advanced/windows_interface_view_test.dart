import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/interface.dart';
import 'package:onexray/pages/advanced/tunnel/windows.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/policy_editor.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/launch/setup.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

PolicyEditorService _service(ConnectionPlatform platform) {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final coordinator = ConnectionCoordinator(database: db);
  addTearDown(() async {
    coordinator.dispose();
    await db.close();
  });
  return PolicyEditorService(coordinator: coordinator, platform: platform);
}

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: AppTheme.material(Brightness.light, mobile: true),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => ShadTheme(
    data: AppTheme.shad(Brightness.light, mobile: true),
    child: child!,
  ),
  home: child,
);

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(427, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  testWidgets(
    'Windows CIDRs use inline drafts and the existing validation gate',
    (tester) async {
      _viewport(tester);
      final original = ConnectionConfiguration();
      final controller = PolicyEditorController(
        draft: PolicyEditorDraft(original),
        service: _service(ConnectionPlatform.windows),
      );
      addTearDown(controller.dispose);
      var openedInterfaces = 0;
      await tester.pumpWidget(
        _app(
          WindowsVpnView(
            controller: controller,
            openInterface: (_, _) async {
              openedInterfaces++;
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(WindowsVpnView)),
      )!;
      FilledButton save() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, l.prototypeSave),
      );
      expect(find.byType(SettingSection), findsNothing);
      expect(find.text('0 / 64'), findsOneWidget);
      expect(find.text(l.prototypeNoBypassNetworks), findsOneWidget);
      expect(save().onPressed, isNull);
      await tester.ensureVisible(
        find.text(l.prototypeChooseInterfaceBeforeSaving),
      );
      await tester.tap(find.text(l.prototypeChooseInterfaceBeforeSaving));
      await tester.pumpAndSettle();
      expect(openedInterfaces, 1);
      await tester.ensureVisible(find.text(l.prototypeAddNetwork));
      await tester.tap(find.text(l.prototypeAddNetwork));
      await tester.pumpAndSettle();
      expect(find.text(l.prototypeNoBypassNetworks), findsNothing);
      expect(find.text('0 / 64'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('windows-cidr-row:0'))).height,
        50,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, TextDirection.ltr);
      expect(field.decoration!.labelText, isNull);
      expect(field.decoration!.hintText, '192.168.1.0/24');
      await tester.enterText(find.byType(TextField), ' 192.168.1.0/24 ');
      await tester.pumpAndSettle();
      expect(find.text('1 / 64'), findsOneWidget);
      expect(controller.strings('windows', 'excludedCidrs'), [
        ' 192.168.1.0/24 ',
      ]);
      controller.update('xrayOutboundInterfaceName', 'Ethernet');
      await tester.pumpAndSettle();
      expect(save().onPressed, isNotNull);
      expect(
        controller.service
            .validate(controller.draft!)
            .toWindowsPolicy()
            .toJson()['excludedCidrs'],
        ['192.168.1.0/24'],
      );
      await tester.enterText(find.byType(TextField), 'fd00::/64');
      controller.update('ipv6Enabled', false);
      await tester.pumpAndSettle();
      expect(save().onPressed, isNull);
      expect(controller.validationHint(l), l.prototypeIpv6BypassConflict);
      await tester.tap(find.byTooltip(l.prototypeRemoveBypassNetworkNumber(1)));
      await tester.pumpAndSettle();
      expect(find.text('0 / 64'), findsOneWidget);
      expect(controller.strings('windows', 'excludedCidrs'), isEmpty);
      expect(original.policy.toJson()['windows']['excludedCidrs'], isEmpty);
      expect(original.policy.xrayOutboundInterfaceName, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Windows counts nonblank CIDRs while limiting fields to 64 in RTL',
    (tester) async {
      _viewport(tester);
      final controller = PolicyEditorController(
        draft: PolicyEditorDraft(ConnectionConfiguration()),
        service: _service(ConnectionPlatform.windows),
      );
      addTearDown(controller.dispose);
      controller.update('excludedCidrs', [
        ...List.generate(63, (index) => '192.168.$index.0/24'),
        ' ',
      ], section: 'windows');
      await tester.pumpWidget(
        _app(
          WindowsVpnView(
            controller: controller,
            openInterface: (_, _) async => null,
          ),
          locale: const Locale('fa'),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(WindowsVpnView)),
      )!;
      expect(find.text('63 / 64'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('63 / 64')).textDirection,
        TextDirection.ltr,
      );
      expect(find.byType(TextField), findsNWidgets(64));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, l.prototypeAddNetwork),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).textDirection,
        TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [
    ConnectionPlatform.windows,
    ConnectionPlatform.linux,
  ]) {
    testWidgets(
      '$platform interface selection preserves names, addresses and retry',
      (tester) async {
        _viewport(tester);
        final original = ConnectionConfiguration();
        final controller =
            OutboundInterfaceController(
                draft: PolicyEditorDraft(original),
                service: _service(platform),
              )
              ..interfaces = const [
                SetupInterface('Wi-Fi (en0)', [
                  '192.0.2.10',
                  '2001:db8::10',
                ], true),
                SetupInterface('Ethernet', ['192.0.2.20'], false),
              ]
              ..loading = false;
        addTearDown(controller.dispose);
        var retries = 0;
        await tester.pumpWidget(
          _app(
            OutboundInterfaceView(
              controller: controller,
              onRetry: () => retries++,
            ),
            locale: const Locale('fa'),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(OutboundInterfaceView));
        final l = AppLocalizations.of(context)!;
        FilledButton save() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, l.prototypeSave),
        );
        expect(controller.value['xrayOutboundInterfaceName'], isEmpty);
        expect(save().onPressed, isNull);
        expect(find.text('Wi-Fi (en0)'), findsOneWidget);
        expect(find.text('192.0.2.10\n2001:db8::10'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.text('192.0.2.10\n2001:db8::10'))
              .textDirection,
          TextDirection.ltr,
        );
        expect(
          tester
              .widget<Text>(find.text(l.prototypeCurrentInternetInterface))
              .style!
              .color,
          ColorManager.palette(context).primary,
        );
        expect(
          tester.getSize(find.byType(ShadRadio<String>).first),
          const Size(17, 17),
        );
        expect(find.text(l.prototypeManagedInterfaceNotice), findsOneWidget);
        await tester.tap(find.text('Ethernet'));
        await tester.pumpAndSettle();
        expect(controller.value['xrayOutboundInterfaceName'], 'Ethernet');
        expect(save().onPressed, isNotNull);
        expect(original.policy.xrayOutboundInterfaceName, isEmpty);
        controller.failed = true;
        controller.notify();
        await tester.pumpAndSettle();
        expect(save().onPressed, isNull);
        await tester.tap(find.text(l.prototypeRetry));
        await tester.pumpAndSettle();
        expect(retries, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
