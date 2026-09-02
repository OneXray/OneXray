import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/app_update/dialog.dart';
import 'package:onexray/pages/settings/desktop/controller.dart';
import 'package:onexray/pages/settings/desktop/page.dart';
import 'package:onexray/pages/settings/theme/page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
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
      home: Scaffold(body: SafeArea(child: child)),
    );
  }

  testWidgets('desktop settings merge startup and macOS options', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    void noop() {}
    await tester.pumpWidget(
      app(
        DesktopSettingsView(
          state: const DesktopSettingsPageState(
            launchAtLogin: LaunchAtLoginStatus.enabled(),
            startHidden: true,
            hideDockIcon: true,
            loading: false,
          ),
          showMacOSOptions: true,
          onLaunchAtLoginChanged: (_) {},
          onStartHiddenChanged: (_) {},
          onHideDockIconChanged: (_) {},
          onOpenSystemSettings: noop,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Launch at Login'), findsOneWidget);
    expect(find.text('Start Hidden'), findsOneWidget);
    expect(find.text('Connect on App Launch'), findsNothing);
    expect(find.text('Hide icon in Dock'), findsOneWidget);
    expect(find.byType(ShadSwitch), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop window behavior does not depend on login registration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(
        DesktopSettingsView(
          state: const DesktopSettingsPageState(
            launchAtLogin: LaunchAtLoginStatus.unavailable(),
            loading: false,
          ),
          showMacOSOptions: false,
          onLaunchAtLoginChanged: (_) {},
          onStartHiddenChanged: (_) {},
          onHideDockIconChanged: (_) {},
          onOpenSystemSettings: () {},
        ),
      ),
    );
    await tester.pump();

    final switches = tester.widgetList<ShadSwitch>(find.byType(ShadSwitch));
    expect(switches.map((item) => item.enabled), [false, true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme choice uses the shared selected indicator', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(ThemeChoiceView(selected: ThemeCode.dark, onSelected: (_) {})),
    );
    await tester.pump();

    expect(find.text('Follow the device appearance'), findsOneWidget);
    expect(find.text('Always use the dark appearance'), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('update dialog keeps long notes scrollable with all actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notes = List.generate(
      30,
      (index) => '- Release note item ${index + 1}',
    ).join('\n');
    final info = AppUpdateInfo(
      currentVersion: '26.7.3',
      latestVersion: '26.8.0',
      releaseNotes: notes,
      releaseUri: Uri.parse('https://example.com/release'),
      updateUri: Uri.parse('https://example.com/update'),
      destination: AppUpdateDestination.githubRelease,
    );
    await tester.pumpWidget(
      app(
        AppUpdateDialogView(
          updateInfo: info,
          onLater: () {},
          onSkip: () {},
          onUpdate: () {},
          onOpenLink: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Skip This Version'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
