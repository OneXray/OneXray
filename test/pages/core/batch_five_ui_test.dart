import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/log/log_file_viewer/controller.dart';
import 'package:onexray/pages/core/log/log_file_viewer/params.dart';
import 'package:onexray/pages/core/main/controller.dart';
import 'package:onexray/pages/core/main/page.dart';
import 'package:onexray/pages/core/ping/page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/event_bus/service.dart';
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

  Widget app(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
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

  testWidgets('core overview exposes log files without an index page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = CoreRootController();
    addTearDown(controller.close);
    await tester.pumpWidget(
      app(
        BlocProvider.value(
          value: controller,
          child: const Scaffold(body: SafeArea(child: CoreContent())),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Network & Runtime'), findsOneWidget);
    expect(find.text('Data & Updates'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Xray config file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ping settings remain scrollable on phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(const PingPage()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Resolved URL'), findsOneWidget);
    expect(find.text('Auto ping new nodes'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
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
