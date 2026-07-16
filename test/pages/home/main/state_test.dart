import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/main/page.dart';
import 'package:onexray/pages/home/main/state.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/core_routing_mode/state.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  setUp(AppEventBus.new);

  testWidgets('running node takes precedence over selected node', (
    tester,
  ) async {
    final viewState = await _buildViewState(
      tester,
      homeState: HomePageState.initial().copyWith(
        configId: 1,
        configName: 'Selected Node',
        runtimeConfigId: 2,
        runtimeConfigName: 'Running Node',
      ),
      eventState: AppEventBusState.initial().copyWith(
        runningId: 2,
        vpnActionState: VpnActionState.connected,
      ),
    );

    expect(viewState.nodeName, 'Running Node');
  });

  testWidgets('connecting node is resolved from the pending config', (
    tester,
  ) async {
    final viewState = await _buildViewState(
      tester,
      homeState: HomePageState.initial().copyWith(
        configId: 1,
        configName: 'Selected Node',
        runtimeConfigId: 2,
        runtimeConfigName: 'Starting Node',
      ),
      eventState: AppEventBusState.initial().copyWith(
        pendingConfigId: 2,
        vpnActionState: VpnActionState.connecting,
      ),
    );

    expect(viewState.nodeName, 'Starting Node');
  });

  testWidgets('selected node is shown while Core is not running', (
    tester,
  ) async {
    final viewState = await _buildViewState(
      tester,
      homeState: HomePageState.initial().copyWith(
        configId: 1,
        configName: 'Selected Node',
      ),
      eventState: AppEventBusState.initial(),
    );

    expect(viewState.nodeName, 'Selected Node');
  });

  testWidgets('missing node is shown as a placeholder', (tester) async {
    final viewState = await _buildViewState(
      tester,
      homeState: HomePageState.initial(),
      eventState: AppEventBusState.initial(),
    );

    expect(viewState.nodeName, HomeConnectionViewStateBuilder.emptyNodeName);
  });

  testWidgets('disconnected action connects the selected node', (tester) async {
    final viewState = await _buildViewState(
      tester,
      homeState: HomePageState.initial().copyWith(
        configId: 1,
        configName: 'Selected Node',
      ),
      eventState: AppEventBusState.initial(),
    );

    expect(viewState.destructiveAction, isFalse);
    expect(viewState.actionLabel, 'Connect to Selected Node');
  });

  testWidgets('connected action disconnects the running selected node', (
    tester,
  ) async {
    final viewState = await _buildViewState(
      tester,
      homeState: HomePageState.initial().copyWith(
        configId: 1,
        configName: 'Selected Node',
        runtimeConfigId: 1,
        runtimeConfigName: 'Selected Node',
      ),
      eventState: AppEventBusState.initial().copyWith(
        runningId: 1,
        vpnActionState: VpnActionState.connected,
      ),
    );

    expect(viewState.destructiveAction, isTrue);
    expect(viewState.actionLabel, 'Disconnect');
  });

  testWidgets('connected action switches to a different selected node', (
    tester,
  ) async {
    final viewState = await _buildViewState(
      tester,
      homeState: HomePageState.initial().copyWith(
        configId: 1,
        configName: 'Selected Node',
        runtimeConfigId: 2,
        runtimeConfigName: 'Running Node',
      ),
      eventState: AppEventBusState.initial().copyWith(
        runningId: 2,
        vpnActionState: VpnActionState.connected,
      ),
    );

    expect(viewState.destructiveAction, isFalse);
    expect(viewState.actionLabel, 'Switch to Selected Node');
  });

  testWidgets('disconnecting keeps the destructive action style', (
    tester,
  ) async {
    final viewState = await _buildViewState(
      tester,
      homeState: HomePageState.initial().copyWith(
        configId: 1,
        configName: 'Selected Node',
        runtimeConfigId: 1,
        runtimeConfigName: 'Selected Node',
      ),
      eventState: AppEventBusState.initial().copyWith(
        runningId: 1,
        vpnLoading: true,
        vpnActionState: VpnActionState.disconnecting,
      ),
    );

    expect(viewState.loading, isTrue);
    expect(viewState.destructiveAction, isTrue);
    expect(viewState.actionLabel, 'Disconnect');
  });

  testWidgets('Direct action describes start and stop behavior', (
    tester,
  ) async {
    final idleState = await _buildViewState(
      tester,
      homeState: HomePageState.initial(),
      eventState: AppEventBusState.initial().copyWith(
        coreRoutingMode: CoreRoutingMode.direct,
      ),
    );
    final connectedState = await _buildViewState(
      tester,
      homeState: HomePageState.initial(),
      eventState: AppEventBusState.initial().copyWith(
        coreRoutingMode: CoreRoutingMode.direct,
        vpnActionState: VpnActionState.connected,
      ),
    );

    expect(idleState.actionLabel, 'Start direct connection');
    expect(idleState.destructiveAction, isFalse);
    expect(connectedState.actionLabel, 'Disconnect');
    expect(connectedState.destructiveAction, isTrue);
  });

  testWidgets('power action matches the prototype geometry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _testApp(
        HomeConnectionSummary(
          connection: const HomeConnectionViewPageState(
            tone: HomeConnectionTone.disconnected,
            connected: false,
            loading: false,
            destructiveAction: false,
            actionLabel: 'Connect to Selected Node',
            statusText: 'Not Connected',
            nodeName: 'Selected Node',
            summaryDetailText: null,
            locationText: '--',
            downloadText: '--',
            uploadText: '--',
            runModeText: 'TUN',
            statusIcon: LucideIcons.shield,
          ),
          xrayProfileName: 'Simple Profile',
          routingMode: CoreRoutingMode.rule,
          pendingRoutingMode: null,
          onToggleConnection: _noop,
          onShowNodeInfo: _noop,
          onShowXrayProfile: _noop,
          onRoutingModeChanged: _noopRoutingMode,
        ),
      ),
    );

    final button = tester.widget<ShadIconButton>(find.byType(ShadIconButton));
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(button.width, 40);
    expect(button.height, 40);
    expect(button.iconSize, 18);
    expect(button.decoration?.shape, BoxShape.circle);
    expect(tooltip.message, 'Connect to Selected Node');
    final profileRow = find.ancestor(
      of: find.text('Simple Profile'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(profileRow.first).height, greaterThanOrEqualTo(40));
    for (final label in ['Rule', 'Global', 'Direct']) {
      final modeButton = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(modeButton.first).height, greaterThanOrEqualTo(40));
    }
  });

  testWidgets('connected power action uses the running color', (tester) async {
    await tester.pumpWidget(
      _testApp(
        HomeConnectionSummary(
          connection: const HomeConnectionViewPageState(
            tone: HomeConnectionTone.connected,
            connected: true,
            loading: false,
            destructiveAction: true,
            actionLabel: 'Disconnect',
            statusText: 'Connected',
            nodeName: 'Running Node',
            summaryDetailText: null,
            locationText: 'Singapore',
            downloadText: '1 MB/s',
            uploadText: '128 KB/s',
            runModeText: 'TUN',
            statusIcon: LucideIcons.shieldCheck,
          ),
          xrayProfileName: 'Simple Profile',
          routingMode: CoreRoutingMode.rule,
          pendingRoutingMode: null,
          onToggleConnection: _noop,
          onShowNodeInfo: _noop,
          onShowXrayProfile: _noop,
          onRoutingModeChanged: _noopRoutingMode,
        ),
      ),
    );

    final button = tester.widget<ShadIconButton>(find.byType(ShadIconButton));
    expect(button.backgroundColor, AppPalette.light.runningBadge);
    expect(button.foregroundColor, AppPalette.light.runningBadgeForeground);
    expect(button.hoverForegroundColor, AppPalette.light.destructive);
  });

  testWidgets('Direct mode does not display the selected node as running', (
    tester,
  ) async {
    final viewState = await _buildViewState(
      tester,
      homeState: HomePageState.initial().copyWith(
        configId: 1,
        configName: 'Selected Node',
      ),
      eventState: AppEventBusState.initial().copyWith(
        coreRoutingMode: CoreRoutingMode.direct,
        runningId: DBConstants.defaultId,
        vpnActionState: VpnActionState.connected,
      ),
    );

    expect(viewState.nodeName, HomeConnectionViewStateBuilder.emptyNodeName);
  });
}

void _noop() {}

void _noopRoutingMode(CoreRoutingMode _) {}

Widget _testApp(Widget child) {
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
    home: Scaffold(body: child),
  );
}

Future<HomeConnectionViewPageState> _buildViewState(
  WidgetTester tester, {
  required HomePageState homeState,
  required AppEventBusState eventState,
}) async {
  HomeConnectionViewPageState? viewState;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          viewState = HomeConnectionViewStateBuilder.build(
            context,
            homeState,
            eventState,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return viewState!;
}
