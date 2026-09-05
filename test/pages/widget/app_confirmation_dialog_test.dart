import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/settings_page.dart';

const _open = Key('open-confirmation');
const _filename =
    'OneXray-2026-09-03-user-servers-subscriptions-Age-keys-custom-routing-'
    'Raw-JSON-and-custom-Geodata-backup.zip';

enum _Action { delete, restore, export, clear }

AppConfirmationDialog _dialog(AppLocalizations l, _Action action) =>
    AppConfirmationDialog(
      title: switch (action) {
        _Action.delete => l.prototypeDeleteBackupQuestion,
        _Action.restore => l.prototypeRestoreBackupQuestion,
        _Action.export => l.prototypeExportBackup,
        _Action.clear => l.prototypeClearAllDataQuestion,
      },
      subject: action == _Action.clear ? null : _filename,
      content: switch (action) {
        _Action.delete => l.prototypeDeleteBackupWarning,
        _Action.restore => l.prototypeRestoreBackupWarning,
        _Action.export => l.prototypeBackupTransferWarning,
        _Action.clear => l.prototypeClearAllDataWarning,
      },
      cancelLabel: l.prototypeCancel,
      confirmLabel: switch (action) {
        _Action.delete => l.prototypeDelete,
        _Action.restore => l.prototypeConfirmRestore,
        _Action.export => l.prototypeContinue,
        _Action.clear => l.prototypeConfirmClearData,
      },
      destructive: action == _Action.delete || action == _Action.clear,
      expandConfirm: action == _Action.restore || action == _Action.export,
      barrierDismissible: false,
    );

Future<void> _pumpDialog(
  WidgetTester tester, {
  required _Action action,
  Locale locale = const Locale('en'),
  double width = 427,
  ValueChanged<bool>? onResult,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.material(Brightness.light, mobile: true),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: _open,
            onPressed: () async {
              final confirmed = await _dialog(
                AppLocalizations.of(context)!,
                action,
              ).show(context);
              onResult?.call(confirmed);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
}

Finder get _surface => find
    .descendant(of: find.byType(Dialog), matching: find.byType(Material))
    .first;

void main() {
  for (final action in _Action.values) {
    testWidgets('mobile $action uses its correct footer width', (tester) async {
      await _pumpDialog(tester, action: action, locale: const Locale('zh'));

      expect(
        MediaQuery.sizeOf(tester.element(find.byType(AppConfirmationDialog)))
            .width,
        427,
      );
      final surface = tester.getRect(_surface);
      final cancel = tester.getRect(find.byType(OutlinedButton));
      final confirm = tester.getRect(find.byType(FilledButton));
      expect(surface.width, closeTo(427 - 38, 0.01));
      expect(surface.center.dx, closeTo(427 / 2, 0.01));
      expect(confirm.right, closeTo(surface.right - 16, 1));
      expect(confirm.left - cancel.right, closeTo(10, 0.01));
      expect(cancel.height, 42);
      expect(confirm.height, 42);
      if (action == _Action.delete || action == _Action.clear) {
        final label = tester.getRect(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.byType(Text),
          ),
        );
        expect(
          confirm.width,
          closeTo(label.width + AppSpacing.buttonHorizontal * 2, 0.01),
        );
        expect(cancel.left, greaterThan(surface.left + 16));
      } else {
        expect(cancel.left, closeTo(surface.left + 16, 1));
        expect(confirm.width, greaterThan(cancel.width * 2));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in AppLocalizations.supportedLocales) {
    for (final action in _Action.values) {
      testWidgets('$locale $action contains long filenames and warnings', (
        tester,
      ) async {
        await _pumpDialog(tester, action: action, locale: locale, width: 390);

        final dialog = tester.widget<AppConfirmationDialog>(
          find.byType(AppConfirmationDialog),
        );
        final surface = tester.getRect(_surface);
        expect(
          Directionality.of(tester.element(find.byType(AppConfirmationDialog))),
          locale.languageCode == 'fa' ? TextDirection.rtl : TextDirection.ltr,
        );
        for (final text in [
          dialog.title,
          if (dialog.subject != null) dialog.subject!,
          dialog.content,
        ]) {
          final bounds = tester.getRect(find.text(text));
          expect(bounds.left, greaterThanOrEqualTo(surface.left));
          expect(bounds.right, lessThanOrEqualTo(surface.right));
          expect(bounds.top, greaterThanOrEqualTo(surface.top));
          expect(bounds.bottom, lessThanOrEqualTo(surface.bottom));
        }
        for (final type in [OutlinedButton, FilledButton]) {
          final button = find.byType(type);
          final bounds = tester.getRect(button);
          final label = tester.getRect(
            find.descendant(of: button, matching: find.byType(Text)),
          );
          expect(label.left, greaterThanOrEqualTo(bounds.left));
          expect(label.right, lessThanOrEqualTo(bounds.right));
          expect(label.top, greaterThanOrEqualTo(bounds.top));
          expect(label.bottom, lessThanOrEqualTo(bounds.bottom));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'cancel and close return false; only confirmation runs the action',
    (tester) async {
      bool? result;
      var actionCalls = 0;
      await _pumpDialog(
        tester,
        action: _Action.clear,
        onResult: (confirmed) {
          result = confirmed;
          if (confirmed) actionCalls++;
        },
      );
      for (final dismiss in [OutlinedButton, IconButton]) {
        await tester.tap(find.byType(dismiss));
        await tester.pumpAndSettle();
        expect(find.byType(AppConfirmationDialog), findsNothing);
        expect(result, isFalse);
        expect(actionCalls, 0);
        result = null;
        await tester.tap(find.byKey(_open));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(actionCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('backdrop does not dismiss a destructive confirmation', (
    tester,
  ) async {
    bool? result;
    await _pumpDialog(
      tester,
      action: _Action.clear,
      onResult: (confirmed) => result = confirmed,
    );

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byType(AppConfirmationDialog), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
