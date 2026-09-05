import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/log/log_file_viewer/controller.dart';
import 'package:onexray/pages/core/log/log_file_viewer/params.dart';
import 'package:onexray/pages/core/ping/page.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/settings/auto_update/page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late AppEventBus eventBus;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    eventBus = AppEventBus();
  });

  tearDown(() async {
    await eventBus.close();
  });

  Widget app(Widget child, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, appChild) => ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadBlueColorScheme.light(),
          radius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: appChild ?? const SizedBox.shrink(),
      ),
      home: child,
    );
  }

  testWidgets('ping settings remain scrollable on phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(const PingPage()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Speed test URL'), findsWidgets);
    expect(find.text('Auto ping new nodes'), findsNothing);
    expect(find.byType(PageActionBar), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(SettingSelect<double>), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('runtime preference fields fit ${locale.toLanguageTag()}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final page in [const PingPage(), const AutoUpdatePage()]) {
        await tester.pumpWidget(app(page, locale: locale));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(PageActionBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('ping settings restore a custom URL', (tester) async {
    final pingState = PingState()
      ..url = PingUrl.custom
      ..customUrl = 'https://example.com/ping';
    await pingState.saveToPreferences();

    await tester.pumpWidget(app(const PingPage()));
    await tester.pump(const Duration(milliseconds: 100));

    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.controller?.text, 'https://example.com/ping');
    expect(find.text('Resolved URL'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('log viewer controller reads the current file tail', () async {
    final tempDir = await Directory.systemTemp.createTemp('onexray-log-test');
    addTearDown(() => tempDir.delete(recursive: true));
    final logFile = File('${tempDir.path}/access.log');
    await logFile.writeAsString('first line\nsecond line\n');

    final controller = LogFileViewerController(
      LogFileViewerParams(title: 'access log', path: logFile.path),
    );
    addTearDown(controller.close);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.state.lines, ['first line', 'second line']);
    expect(controller.state.fileExists, isTrue);
  });
}
