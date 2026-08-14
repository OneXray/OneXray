import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/first_run/controller.dart';
import 'package:onexray/pages/launch/first_run/page.dart';
import 'package:onexray/pages/launch/privacy/page.dart';
import 'package:onexray/pages/settings/app_update/dialog.dart';
import 'package:onexray/pages/settings/desktop/controller.dart';
import 'package:onexray/pages/settings/desktop/page.dart';
import 'package:onexray/pages/settings/general/controller.dart';
import 'package:onexray/pages/settings/general/page.dart';
import 'package:onexray/pages/settings/main/controller.dart';
import 'package:onexray/pages/settings/main/page.dart';
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

  SettingsOverviewView settingsView({
    bool showDesktopSettings = false,
    bool useDockIconLabel = false,
  }) {
    void noop() {}
    return SettingsOverviewView(
      state: const SettingsPageState(
        appVersion: '26.7.3',
        xrayVersion: '26.7.11',
      ),
      showAppIcon: true,
      useDockIconLabel: useDockIconLabel,
      showReview: true,
      showDesktopSettings: showDesktopSettings,
      onAutoUpdate: noop,
      onCheckUpdate: noop,
      onClearData: noop,
      onBackup: noop,
      onAppIcon: noop,
      onTheme: noop,
      onLanguage: noop,
      onGeneralSettings: noop,
      onDesktopSettings: noop,
      onDocumentation: noop,
      onReview: noop,
      onTelegram: noop,
      onIssue: noop,
      onSourceCode: noop,
      onCredits: noop,
      onPrivacy: noop,
    );
  }

  testWidgets('settings uses approved compact section order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(settingsView()));
    await tester.pump();

    final dataY = tester.getTopLeft(find.text('Data & Updates')).dy;
    final appY = tester.getTopLeft(find.text('App Settings')).dy;
    final versionY = tester.getTopLeft(find.text('Version')).dy;
    final supportY = tester.getTopLeft(find.text('Support & About')).dy;
    expect(dataY, lessThan(appY));
    expect(appY, lessThan(versionY));
    expect(versionY, lessThan(supportY));
    expect(find.text('26.7.3'), findsOneWidget);
    expect(find.textContaining('+412'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings keeps configuration controls off the overview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(settingsView()));
    await tester.pump();

    expect(find.text('General'), findsOneWidget);
    expect(find.text('Connect on App Launch'), findsNothing);
    expect(find.byType(ShadSwitch), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('general settings exposes startup and User-Agent choices', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(
        GeneralSettingsView(
          state: const GeneralSettingsPageState(
            connectOnAppLaunch: true,
            userAgent: 'OneXray/26.8.4 (net.yuandev.onexray; build:1; macos)',
            loading: false,
          ),
          onConnectOnAppLaunchChanged: (_) {},
          onUserAgentModeChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Connect on App Launch'), findsOneWidget);
    expect(find.text('System User-Agent'), findsOneWidget);
    expect(find.text('OneXray User-Agent'), findsOneWidget);
    expect(
      find.text('OneXray/26.8.4 (net.yuandev.onexray; build:1; macos)'),
      findsOneWidget,
    );
    expect(find.byType(ShadSwitch), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(
      const GeneralSettingsPageState().userAgentMode,
      DownloadUserAgentMode.oneXray,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings labels the macOS app icon as a Dock icon', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(settingsView(useDockIconLabel: true)));
    await tester.pump();

    expect(find.text('Dock Icon'), findsOneWidget);
    expect(
      find.text('The selected icon is applied to the macOS Dock.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings uses two columns on desktop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(settingsView()));
    await tester.pump();

    final data = tester.getTopLeft(find.text('Data & Updates'));
    final appSettings = tester.getTopLeft(find.text('App Settings'));
    final version = tester.getTopLeft(find.text('Version'));
    final support = tester.getTopLeft(find.text('Support & About'));
    expect(appSettings.dx, closeTo(data.dx, 1));
    expect(version.dx, greaterThan(data.dx));
    expect(support.dx, closeTo(version.dx, 1));
    expect(appSettings.dy, greaterThan(data.dy));
    expect(support.dy, greaterThan(version.dy));
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('settings shows one desktop settings navigation row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(settingsView(showDesktopSettings: true)));
    await tester.pump();

    expect(find.text('Desktop'), findsOneWidget);
    expect(find.text('Toolbox'), findsNothing);
    expect(find.text('Start Hidden'), findsNothing);
    expect(find.text('Connect on App Launch'), findsNothing);
    expect(find.byType(ShadSwitch), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first run keeps IPv6 before outbound interface and scrolls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(
        FirstRunView(
          state: const FirstRunPageState(),
          showInterfaces: true,
          onCountryChanged: (_) {},
          onInterfaceChanged: (_) {},
          onIPv6Changed: (_) {},
          onContinue: () {},
        ),
      ),
    );
    await tester.pump();

    final ipv6Y = tester.getTopLeft(find.text('Enable IPv6')).dy;
    final interfaceY = tester
        .getTopLeft(find.text('Outbound Network Interface'))
        .dy;
    expect(ipv6Y, lessThan(interfaceY));
    expect(find.text('Next Step'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Next Step'), findsOneWidget);
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

  testWidgets('privacy document scrolls above one fixed action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final document = List.generate(
      24,
      (index) => '## Section ${index + 1}\nPrivacy policy text.',
    ).join('\n\n');
    await tester.pumpWidget(
      app(PrivacyView(markdown: document, onOpenLink: (_) {}, onAccept: () {})),
    );
    await tester.pump();

    expect(find.text('Accept and Continue'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    expect(find.text('Accept and Continue'), findsOneWidget);
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
