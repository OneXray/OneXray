import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/backup/controller.dart';
import 'package:onexray/pages/settings/backup/page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// The reply share_plus maps to a share sheet the user dismissed.
const _dismissedReply = '';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;

  late AppEventBus eventBus;
  late Directory supportDir;
  late File backupFile;
  late List<MethodCall> shareCalls;
  late Object? shareReply;

  setUp(() async {
    // Menu titles are read through AppEventBus, and BackupService resolves the
    // backup directory through path_provider.
    eventBus = AppEventBus();
    supportDir = await Directory.systemTemp.createTemp('onexray_backup_test');
    backupFile = File(
      p.join(supportDir.path, 'backup', 'OneXray-2026-09-02.zip'),
    );
    await backupFile.parent.create(recursive: true);
    await backupFile.writeAsBytes(const [0x50, 0x4b, 0x05, 0x06]);

    shareCalls = <MethodCall>[];
    shareReply = 'net.yuandev.onexray.receiver';
    messenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (call) async => call.method == 'getApplicationSupportDirectory'
          ? supportDir.path
          : null,
    );
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      shareCalls.add(call);
      final reply = shareReply;
      if (reply is PlatformException) {
        throw reply;
      }
      return reply as String?;
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_pathProviderChannel, null);
    messenger.setMockMethodCallHandler(_shareChannel, null);
    await eventBus.close();
    if (supportDir.existsSync()) {
      await supportDir.delete(recursive: true);
    }
  });

  testWidgets('sharing a backup row anchors the share sheet on that row', (
    tester,
  ) async {
    await _pumpBackupPage(tester);
    expect(find.text(p.basename(backupFile.path)), findsOneWidget);

    await _selectRowMenu(tester, IconMenuId.share);

    expect(tester.takeException(), isNull);
    expect(shareCalls, hasLength(1));
    final arguments = _shareArguments(shareCalls.single);
    expect(arguments['paths'], [backupFile.path]);
    // The anchor has to be the row's own box. Rows are built by a sliver
    // itemBuilder, whose context resolves to a RenderSliver, so the row has to
    // hand its callbacks a context of its own.
    final rowRect = tester.getRect(find.byType(DataListRow));
    expect(arguments['originWidth'], rowRect.width);
    expect(arguments['originHeight'], rowRect.height);
    expect(find.text('Share successfully'), findsOneWidget);

    await _drainToast(tester);
  });

  testWidgets('sharing survives a row callback bound to the sliver context', (
    tester,
  ) async {
    final controller = BackupController();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _app(
        _SliverContextRowHost(
          controller: controller,
          file: _fileInfo(backupFile),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    // The sliver context cannot supply an anchor, but it must not abort the
    // share either.
    expect(tester.takeException(), isNull);
    expect(shareCalls, hasLength(1));
    final arguments = _shareArguments(shareCalls.single);
    expect(arguments['paths'], [backupFile.path]);
    expect(arguments.containsKey('originWidth'), isFalse);
    expect(find.text('Share successfully'), findsOneWidget);

    await _drainToast(tester);
  });

  testWidgets('a dismissed share sheet reports nothing', (tester) async {
    shareReply = _dismissedReply;

    await _pumpBackupPage(tester);
    await _selectRowMenu(tester, IconMenuId.share);

    expect(tester.takeException(), isNull);
    expect(shareCalls, hasLength(1));
    expect(find.text('Share successfully'), findsNothing);
    expect(find.text('Share failed'), findsNothing);
  });

  testWidgets('a rejected share reports a failure', (tester) async {
    shareReply = PlatformException(code: 'Share failed');

    await _pumpBackupPage(tester);
    await _selectRowMenu(tester, IconMenuId.share);

    expect(tester.takeException(), isNull);
    expect(shareCalls, hasLength(1));
    expect(find.text('Share failed'), findsOneWidget);

    await _drainToast(tester);
  });
}

/// Pumps [BackupPage] and waits for the disk read its controller starts.
///
/// The row list comes from real file I/O. It only lands while
/// [WidgetTester.runAsync] gives the real event loop a turn, and the
/// continuations it schedules only run on the next pump, so the two have to
/// alternate until the controller reports the files it found.
Future<void> _pumpBackupPage(WidgetTester tester) async {
  // The action bar does not fit the default 800x600 test surface.
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(_app(const BackupPage()));
  final controller = BlocProvider.of<BackupController>(
    tester.element(find.byType(BlocBuilder<BackupController, BackupPageState>)),
  );
  for (var turn = 0; turn < 50 && controller.state.files.isEmpty; turn++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(controller.state.files, isNotEmpty);
  await tester.pumpAndSettle();
}

/// Picks [menuId] the way the row's overflow menu does.
///
/// The menu entries are platform gated: `IconMenuId.share` is hidden on Linux,
/// so the entry itself cannot be tapped on every host. Calling the callback the
/// page captured still covers the wiring under test, which is the context the
/// row hands to the controller.
Future<void> _selectRowMenu(WidgetTester tester, IconMenuId menuId) async {
  final menuButton = tester.widget<AppMenuButton<IconMenuId>>(
    find.byType(AppMenuButton<IconMenuId>),
  );
  menuButton.onSelected(menuId);
  await tester.pumpAndSettle();
}

/// Lets the toast time out so the test ends without pending timers.
Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Hosts a row whose callbacks are bound to the raw `itemBuilder` context, the
/// wiring that used to abort the share.
class _SliverContextRowHost extends StatelessWidget {
  const _SliverContextRowHost({required this.controller, required this.file});

  final BackupController controller;
  final FileInfo file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.separated(
        itemBuilder: (sliverContext, index) => SizedBox(
          height: 56,
          child: TextButton(
            onPressed: () =>
                controller.moreAction(sliverContext, file, IconMenuId.share),
            child: const Text('trigger'),
          ),
        ),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemCount: 1,
      ),
    );
  }
}

/// Mirrors the app shell from `lib/pages/main/router.dart`, which owns the
/// ShadTheme and the toaster the controller reports through.
Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, appChild) => ShadTheme(
      data: AppTheme.shad(Theme.of(context).brightness),
      child: ShadToaster(child: appChild ?? const SizedBox.shrink()),
    ),
    home: child,
  );
}

FileInfo _fileInfo(File file) =>
    FileInfo(p.basename(file.path), file.path)
      ..timestamp = file.lastModifiedSync();

Map<String, Object?> _shareArguments(MethodCall call) {
  expect(call.method, 'share');
  return (call.arguments as Map).cast<String, Object?>();
}
