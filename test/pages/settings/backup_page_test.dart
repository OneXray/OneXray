import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/backup/page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  for (final locale in const [
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('en'),
    Locale('ru'),
    Locale('fa'),
  ]) {
    testWidgets(
      'desktop backup actions have bounded content in ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(935, 688);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.material(Brightness.light, mobile: false),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => ShadTheme(
              data: AppTheme.shad(Brightness.light, mobile: false),
              child: child!,
            ),
            home: const BackupPage(),
          ),
        );
        // Storage is deliberately not prepared: this checks presentation,
        // including the unavailable-directory branch, without native I/O.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final l10n = AppLocalizations.of(
          tester.element(find.byType(PageActionBar)),
        )!;
        expect(find.text(l10n.prototypeBackupRestoreHint), findsNothing);
        for (final label in [
          l10n.prototypeCreateBackup,
          l10n.prototypeImportBackup,
          l10n.prototypeRestoreSelectedBackup,
        ]) {
          final text = find.text(label);
          final button = find.ancestor(
            of: text,
            matching: find.byType(ShadButton),
          );
          expect(button, findsOneWidget);
          final buttonRect = tester.getRect(button);
          final textRect = tester.getRect(text);
          expect(buttonRect.width.isFinite, isTrue);
          expect(textRect.left, greaterThanOrEqualTo(buttonRect.left));
          expect(textRect.right, lessThanOrEqualTo(buttonRect.right));
        }
        final restore = tester.widget<ShadButton>(
          find.ancestor(
            of: find.text(l10n.prototypeRestoreSelectedBackup),
            matching: find.byType(ShadButton),
          ),
        );
        expect(restore.enabled, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
