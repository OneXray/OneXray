import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/backup/codec.dart';
import 'package:onexray/core/backup/storage.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/backup/page.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:onexray/pages/shared/widgets/page_action_bar.dart';
import 'package:onexray/pages/shared/widgets/settings_page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/advanced/xray/geodata/service.dart';
import 'package:onexray/service/settings/backup/assets.dart';
import 'package:onexray/service/settings/backup/service.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../service/settings/backup/service_test.dart'
    show MemoryBackupPreferences, MemoryBackupStorage;

void main() {
  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(
      done(),
      true,
      reason: 'The bounded async operation did not complete',
    );
    await tester.pump();
  }

  late BackupService service;
  late MemoryBackupPreferences preferences;
  late MemoryBackupStorage storage;
  late BackupAssets assets;
  var restored = 0;

  setUp(() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final geodata = GeoDataService.forTesting(
      database: db,
      directory: '../references/onexray-tests/unused-backup-ui',
      download: (_, _) async => fail('No download'),
      count: (_, _, _) async => fail('No indexing'),
      copyBundled: (_) async => fail('No bundled copy'),
    );
    assets = BackupAssets(db, geodata);
    preferences = MemoryBackupPreferences();
    storage = MemoryBackupStorage();
    restored = 0;
    service = BackupService.forTesting(
      storage: storage,
      preferences: preferences,
      assets: assets,
      now: () => DateTime(2026, 9, 16),
      restore: (commit) async {
        await commit();
        restored++;
      },
    );
    addTearDown(service.close);
  });

  Widget app(Locale locale) => MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: AppLocalePolicy.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => ShadTheme(
      data: ShadThemeData(colorScheme: const ShadBlueColorScheme.light()),
      child: ShadToaster(child: child ?? const SizedBox.shrink()),
    ),
    home: BackupPage(service: service),
  );

  for (final locale in const [
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ru'),
    Locale('fa'),
  ]) {
    for (final width in const [390.0, 1160.0]) {
      testWidgets(
        'backup page and overwrite confirmation fit $locale / $width',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 844);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          preferences.settings = const BackupSettings(
            target: BackupTarget(
              'fixture',
              'OneDrive / a-very-long-selected-directory-name / OneXray-backup.json',
            ),
          );
          await tester.pumpWidget(app(locale));
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(PageActionBar)),
          )!;
          expect(find.text(l.backupTitle), findsOneWidget);
          expect(storage.writes, 0);
          final bottom = tester.getBottomRight(find.byType(PageActionBar)).dy;
          await tester.drag(
            find.byType(SettingsPageScroll),
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
          expect(tester.getBottomRight(find.byType(PageActionBar)).dy, bottom);
          await tester.tap(find.text(l.backupNow));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(AppConfirmationDialog), findsOneWidget);
          expect(storage.writes, 0);
          await tester.tap(find.text(l.prototypeCancel));
          await tester.pumpAndSettle();
          expect(preferences.settings.confirmed, false);
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'manual overwrite then preview and offline restore; no consent on cancelled restore',
    (tester) async {
      await service.select(create: false);
      await tester.pumpWidget(app(const Locale('en')));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(PageActionBar)),
      )!;
      await tester.tap(find.text(l.backupNow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(
        find.descendant(
          of: find.byType(AppConfirmationDialog),
          matching: find.text(l.backupNow),
        ),
      );
      await pumpUntil(
        tester,
        () => storage.bytes != null && service.state.operation == null,
      );
      await tester.pumpAndSettle();
      expect(preferences.settings.confirmed, true);
      expect(decodeBackup(storage.bytes!).coreConfigs, isEmpty);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.backupRestore));
      await pumpUntil(
        tester,
        () => find.byType(AppConfirmationDialog).evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AppConfirmationDialog), findsOneWidget);
      expect(find.textContaining(l.backupEmptyWarning), findsOneWidget);
      expect(restored, 0);
      await tester.tap(find.text(l.prototypeCancel));
      await tester.pumpAndSettle();
      expect(restored, 0);
      expect(storage.writes, 1);
      await tester.tap(find.text(l.backupRestore));
      await pumpUntil(
        tester,
        () => find.byType(AppConfirmationDialog).evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(
        find.descendant(
          of: find.byType(AppConfirmationDialog),
          matching: find.text(l.backupRestore),
        ),
      );
      await pumpUntil(
        tester,
        () => restored == 1 && service.state.operation == null,
      );
      expect(storage.writes, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'automatic backup requires explicit target consent and can be disabled',
    (tester) async {
      await service.select(create: false);
      await tester.pumpWidget(app(const Locale('en')));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(PageActionBar)),
      )!;
      expect(tester.widget<ShadSwitch>(find.byType(ShadSwitch)).value, true);
      expect(storage.writes, 0);
      expect(storage.reads, 0);
      await tester.ensureVisible(find.text(l.backupAllow));
      await tester.tap(find.text(l.backupAllow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AppConfirmationDialog), findsOneWidget);
      expect(storage.writes, 0);
      await tester.tap(
        find.descendant(
          of: find.byType(AppConfirmationDialog),
          matching: find.text(l.backupAllow),
        ),
      );
      await pumpUntil(
        tester,
        () => storage.writes == 1 && service.state.operation == null,
      );
      await tester.pumpAndSettle();
      expect(preferences.settings.confirmed, true);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(ShadSwitch));
      await tester.tap(find.byType(ShadSwitch));
      await tester.pumpAndSettle();
      expect(preferences.enabled, false);
      expect(tester.widget<ShadSwitch>(find.byType(ShadSwitch)).value, false);
      expect(storage.writes, 1);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'provider read shows only local loading; leaving skips late preview',
    (tester) async {
      final held = _HeldRead();
      service = BackupService.forTesting(
        storage: held,
        preferences: preferences,
        assets: assets,
        now: DateTime.now,
        restore: (commit) => commit(),
      );
      addTearDown(service.close);
      await service.select(create: false);
      held.bytes = await tester.runAsync(
        () async => encodeBackup(await assets.capture()),
      );
      await tester.pumpWidget(app(const Locale('en')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pump();
      expect(find.byType(ButtonProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      held.finish.complete();
      await pumpUntil(tester, () => service.state.operation == null);
      await tester.pump();
      expect(find.byType(AppConfirmationDialog), findsNothing);
      expect(restored, 0);
      expect(tester.takeException(), null);
    },
  );
}

class _HeldRead extends MemoryBackupStorage {
  final finish = Completer<void>();
  @override
  Future<Uint8List> read(BackupTarget target) async {
    await finish.future;
    return super.read(target);
  }
}
