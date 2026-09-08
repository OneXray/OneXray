import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:onexray/pages/advanced/xray/controller.dart';
import 'package:onexray/pages/advanced/xray/page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/shared/widgets/page_action_bar.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/advanced/platform_policy.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  setUp(() {
    final bus = AppEventBus();
    addTearDown(bus.close);
  });
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
              localizationsDelegates: AppLocalePolicy.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (_, child) => ShadTheme(
                data: AppTheme.shad(Brightness.light, mobile: mobile),
                child: ShadToaster(child: child!),
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
          } else {
            final original = controller.base;
            expect(controller.dirty, isFalse);
            await tester.tap(find.text(l.prototypeSave));
            await tester.pump();
            expect(find.text(l.prototypeSettingsSaved), findsOneWidget);
            expect(controller.saving, isFalse);
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();

            await tester.tap(find.text(l.prototypeRestoreDefaults));
            await tester.pump();
            expect(find.text(l.settingsDefaultsRestored), findsOneWidget);
            expect(find.text(l.prototypeSettingsSaved), findsNothing);
            expect(controller.logsEnabled, isFalse);
            expect(controller.base, same(original));
            expect(controller.dirty, isTrue);
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
    final configuration = ConnectionConfiguration(
      policy: PlatformPolicy.fromJson({
        'log': {'enabled': true},
      }),
    );
    emit(
      state.copyWith(
        base: configuration,
        log: configuration.policy.toJson()['log'] as Map<String, dynamic>,
        systemExtension: systemExtension,
        loading: false,
      ),
    );
  }
}
