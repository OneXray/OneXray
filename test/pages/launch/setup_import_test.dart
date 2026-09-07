import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/setup/page.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/servers/import/page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/launch/setup.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  setUp(() {
    final bus = AppEventBus();
    addTearDown(bus.close);
  });
  for (final mobile in [true, false]) {
    testWidgets('Setup file picker opens directly and cancels ($mobile)', (
      tester,
    ) async {
      final picker = _installPicker();
      var completed = 0;
      final router = await _pumpSetup(
        tester,
        mobile: mobile,
        onImportFinished: () => completed++,
      );
      await _tap(tester, 'Import file');
      expect(picker.calls, 1);
      expect(completed, 0);
      expect(find.byType(ServersImportPage, skipOffstage: false), findsNothing);
      expect(router.canPop(), isFalse);
      picker.result.complete(null);
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(find.byType(SetupView), findsOneWidget);
      expect(find.byType(ServersImportPage, skipOffstage: false), findsNothing);
      expect(router.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Setup reports a file picker error without another dialog', (
    tester,
  ) async {
    final picker = _installPicker();
    var completed = false;
    final router = await _pumpSetup(
      tester,
      onImportFinished: () => completed = true,
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(SetupView)))!;
    await _tap(tester, 'Import file');
    picker.result.completeError(StateError('Cannot read selected file'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.prototypeCannotReadContent), findsOneWidget);
    expect(find.byType(ServersImportPage, skipOffstage: false), findsNothing);
    expect(router.canPop(), isFalse);
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final (label, action) in [
    ('Paste link', ServerImportAction.paste),
    ('Add subscription', ServerImportAction.subscription),
    ('Add JSON manually', ServerImportAction.json),
  ]) {
    testWidgets('Setup opens $label directly and returns on Back or Cancel', (
      tester,
    ) async {
      var completed = 0;
      final router = await _pumpSetup(
        tester,
        onImportFinished: () => completed++,
      );
      for (final exit in ['Back', 'Cancel']) {
        await _tap(tester, label);
        final form = tester.widget<ServerImportFormPage>(
          find.byType(ServerImportFormPage),
        );
        expect(form.action, action);
        expect(form.controller.showSuccessToast, isFalse);
        expect(
          find.byType(ServersImportPage, skipOffstage: false),
          findsNothing,
        );
        form.controller.text.text = 'vless://local';
        form.controller.name.text = 'Provider';
        await _tap(tester, exit);
        expect(find.byType(ServerImportFormPage), findsNothing);
        expect(find.byType(SetupView), findsOneWidget);
        expect(router.canPop(), isFalse);
        expect(tester.takeException(), isNull);
      }
      expect(completed, 2);
    });
  }

  testWidgets('A completed import returns to Setup without popping it', (
    tester,
  ) async {
    var completed = false;
    final router = await _pumpSetup(
      tester,
      onImportFinished: () => completed = true,
    );
    await _tap(tester, 'Paste link');
    Navigator.of(tester.element(find.byType(ServerImportFormPage)))
        .pop(const ServerImportResult(count: 1));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.byType(SetupView), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

// Use the production Setup callback without startup services or user data.
Future<GoRouter> _pumpSetup(
  WidgetTester tester, {
  bool mobile = true,
  required VoidCallback onImportFinished,
}) async {
  tester.view.physicalSize = mobile
      ? const Size(390, 844)
      : const Size(1160, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final setup = RouterPath.router.configuration.routes
      .whereType<GoRoute>()
      .singleWhere((route) => route.path == '/setup');
  final router = GoRouter(
    initialLocation: '/setup',
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) {
          final page = setup.builder!(context, state) as SetupPage;
          return SetupView(
            state: const SetupPageState(step: SetupStep.servers, busy: false),
            requiresInterface: false,
            supportsScan: false,
            onAction: (_) {},
            onAddServer: (action) async {
              await page.addServers(context, action);
              onImportFinished();
            },
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.material(Brightness.light, mobile: mobile),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (_, child) => ShadTheme(
        data: AppTheme.shad(Brightness.light, mobile: mobile),
        child: ShadToaster(child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

_PendingFilePicker _installPicker() {
  final previous = FilePickerPlatform.instance;
  final picker = _PendingFilePicker();
  FilePickerPlatform.instance = picker;
  addTearDown(() => FilePickerPlatform.instance = previous);
  return picker;
}

class _PendingFilePicker extends FilePickerPlatform {
  int calls = 0;
  final result = Completer<PlatformFile?>();

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) {
    calls++;
    return result.future;
  }
}
