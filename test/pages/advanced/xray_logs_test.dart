import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/xray/controller.dart';
import 'package:onexray/pages/advanced/xray/page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  for (final mobile in [true, false]) {
    for (final systemExtension in [true, false]) {
      testWidgets(
        'Xray logs visibility: systemExtension=$systemExtension, mobile=$mobile',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = mobile
              ? const Size(427, 900)
              : const Size(1160, 900);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          final coordinator = ConnectionCoordinator(database: db);
          final controller = _Controller(
            coordinator: coordinator,
            systemExtension: systemExtension,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.material(Brightness.light, mobile: mobile),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (_, child) => ShadTheme(
                data: AppTheme.shad(Brightness.light, mobile: mobile),
                child: child!,
              ),
              home: XrayRuntimePage(
                createController: () => controller,
                onGeodata: (_) {},
                onUpdates: (_) {},
                onSpeedTest: (_) {},
                onLog: (_, _) {},
                onConfig: (_, _) {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(XrayRuntimePage)),
          )!;
          final visibility = systemExtension ? findsNothing : findsOneWidget;
          for (final text in [
            l.prototypeLogs,
            l.prototypeRecordXrayLogs,
            l.prototypeErrorLogLevel,
            l.prototypeRecordDnsQueries,
            l.prototypeHideLogIpAddresses,
            l.prototypeAccessLog,
            l.prototypeErrorLog,
            l.prototypeRestoreDefaults,
            l.prototypeSave,
          ]) {
            expect(find.text(text), visibility);
          }
          expect(find.byType(PageActionBar), visibility);
          for (final text in [
            l.prototypeRuntimeStatus,
            l.prototypeRoutingData,
            l.prototypeDataUpdates,
            l.prototypeSpeedTest,
            l.prototypeRuntimeConfiguration,
          ]) {
            expect(find.text(text), findsOneWidget);
          }
          if (systemExtension) {
            controller.setLog('enabled', false);
            controller.restoreDefaults();
            expect(controller.logsEnabled, isTrue);
            expect(controller.logPath(true), isNull);
            expect(controller.logPath(false), isNull);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          coordinator.dispose();
          await db.close();
        },
      );
    }
  }
}

class _Controller extends XrayRuntimeController {
  _Controller({required super.coordinator, required this.systemExtension});

  final bool systemExtension;

  @override
  Future<void> load({bool showLoading = true}) async {
    emit(
      state.copyWith(
        base: ConnectionConfiguration(),
        log: const {
          'enabled': true,
          'level': 'warning',
          'recordDns': true,
          'maskIp': false,
        },
        systemExtension: systemExtension,
        loading: false,
      ),
    );
  }
}
