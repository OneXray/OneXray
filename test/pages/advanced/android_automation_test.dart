import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/android/automation/controller.dart';
import 'package:onexray/pages/advanced/tunnel/android/automation/page.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/shared/widgets/page_action_bar.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/advanced/tunnel/android/automation/service.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _Host extends AndroidAutomationHostApi {
  AndroidAutomationSettings saved = AndroidAutomationSettings(enabled: false);
  Completer<AndroidAutomationSettings>? pending;
  int resets = 0;
  @override
  Future<AndroidAutomationSettings> read() async => saved;
  @override
  Future<AndroidAutomationSettings> setEnabled(bool enabled) async =>
      saved = pending == null
      ? AndroidAutomationSettings(enabled: enabled, token: 'private-token')
      : await pending!.future;
  @override
  Future<AndroidAutomationSettings> resetToken() async {
    resets++;
    return saved = AndroidAutomationSettings(
      enabled: true,
      token: 'replacement-token',
    );
  }
}

Widget _app(
  AutomationController controller, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double scale = 1,
}) => MaterialApp(
  theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
  locale: locale,
  localizationsDelegates: AppLocalePolicy.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => ShadTheme(
    data: AppTheme.shad(brightness),
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: ShadToaster(child: child!),
    ),
  ),
  home: AndroidAutomationPage(createController: () => controller),
);

void main() {
  test('automation route is registered only for Android', () {
    final segment = AppPageDestination.androidAutomation.segment;
    for (final desktop in [false, true]) {
      expect(
        buildScopedPageRoutes(
          desktop: desktop,
          android: false,
        ).map((r) => r.path),
        isNot(contains(segment)),
      );
    }
    expect(
      buildScopedPageRoutes(desktop: false, android: true).map((r) => r.path),
      contains(segment),
    );
  });

  testWidgets('immediate save, local progress, copy and confirmed reset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final host = _Host();
    String? copied;
    final controller = AutomationController(
      service: AndroidAutomationService(api: host),
      copy: (v) async => copied = v,
    );
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    expect(controller.state.saved!.enabled, isFalse);
    expect(find.byType(PageActionBar), findsNothing);
    host.pending = Completer();
    await tester.tap(find.byKey(const ValueKey('automation-enable')));
    await tester.pump();
    expect(controller.state.writing, 'enable');
    final copyParameters = find.byKey(
      const ValueKey('automation-copy-parameters'),
    );
    expect(tester.widget<OutlinedButton>(copyParameters).onPressed, isNotNull);
    host.pending!.complete(
      AndroidAutomationSettings(enabled: true, token: 'private-token'),
    );
    await tester.pumpAndSettle();
    expect(find.text('private-token'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('automation-copy-token')));
    await tester.pumpAndSettle();
    expect(copied, 'private-token');
    await tester.tap(find.byKey(const ValueKey('automation-reset-token')));
    await tester.pumpAndSettle();
    expect(host.resets, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(host.resets, 0);
    await tester.tap(find.byKey(const ValueKey('automation-reset-token')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(host.resets, 1);
    expect(controller.state.saved!.token, 'replacement-token');
  });

  testWidgets('failed save keeps the previous state and permits retry', (
    tester,
  ) async {
    final host = _Host()..pending = Completer();
    final controller = AutomationController(
      service: AndroidAutomationService(api: host),
    );
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('automation-enable')));
    host.pending!.completeError(StateError('Disk full'));
    await tester.pumpAndSettle();
    expect(controller.state.saved!.enabled, isFalse);
    expect(controller.state.writing, isNull);
    expect(controller.state.error, contains('Disk full'));
    host.pending = null;
    await tester.tap(find.byKey(const ValueKey('automation-enable')));
    await tester.pumpAndSettle();
    expect(controller.state.saved!.enabled, isTrue);
  });

  for (final locale in const [
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ru'),
    Locale('fa'),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('layout $locale $brightness at 320px and enlarged text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final host = _Host()
          ..saved = AndroidAutomationSettings(
            enabled: true,
            token: 'private-token',
          );
        await tester.pumpWidget(
          _app(
            AutomationController(service: AndroidAutomationService(api: host)),
            locale: locale,
            brightness: brightness,
            scale: 1.5,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final parameters = find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.data == AndroidAutomationService.parameters,
        );
        await tester.ensureVisible(parameters);
        await tester.pumpAndSettle();
        expect(
          tester.widget<SelectableText>(parameters).textDirection,
          TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('private-token'), findsNothing);
      });
    }
  }
}
