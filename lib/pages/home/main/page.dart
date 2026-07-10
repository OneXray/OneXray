import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/component/nodes/controller.dart';
import 'package:onexray/pages/home/component/nodes/view.dart';
import 'package:onexray/pages/home/main/actions.dart';
import 'package:onexray/pages/home/main/controller.dart';
import 'package:onexray/pages/home/main/state.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const double _adaptiveBreakpoint = 840;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (context) => HomeController(context))],
      child: BlocBuilder<HomeController, HomePageState>(
        builder: (context, homeState) {
          final controller = context.read<HomeController>();
          return BlocBuilder<AppEventBus, AppEventBusState>(
            builder: (context, eventState) => LayoutBuilder(
              builder: (context, constraints) {
                final connection = controller.buildConnectionViewState(
                  context,
                  homeState,
                  eventState,
                );
                if (constraints.maxWidth >= _adaptiveBreakpoint) {
                  return _adaptiveScaffold(
                    context,
                    controller,
                    homeState,
                    connection,
                    eventState,
                  );
                }
                return _compactScaffold(
                  context,
                  controller,
                  homeState,
                  connection,
                  eventState,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _compactScaffold(
    BuildContext context,
    HomeController controller,
    HomePageState homeState,
    HomeConnectionViewPageState connection,
    AppEventBusState eventState,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.homePageTitle),
        actions: [
          _searchButton(controller, homeState),
          _rightButton(context, controller, eventState),
        ],
      ),
      body: SafeArea(child: _body(context, controller, homeState, connection)),
    );
  }

  Widget _adaptiveScaffold(
    BuildContext context,
    HomeController controller,
    HomePageState homeState,
    HomeConnectionViewPageState connection,
    AppEventBusState eventState,
  ) {
    return Scaffold(
      body: SafeArea(
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
          child: _adaptivePrimary(
            context,
            controller,
            homeState,
            connection,
            eventState,
          ),
        ),
      ),
    );
  }

  Widget _adaptivePrimary(
    BuildContext context,
    HomeController controller,
    HomePageState homeState,
    HomeConnectionViewPageState connection,
    AppEventBusState eventState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _adaptiveHeader(context, controller, homeState, eventState),
        _connectionSummary(context, controller, connection),
        Divider(height: 1, color: ColorManager.border(context)),
        Expanded(child: HomeNodePanel(showSearch: homeState.nodeSearchVisible)),
      ],
    );
  }

  Widget _adaptiveHeader(
    BuildContext context,
    HomeController controller,
    HomePageState homeState,
    AppEventBusState eventState,
  ) {
    return Material(
      color: ColorManager.surface(context),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 20, end: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.homePageTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ColorManager.primaryText(context),
                  ),
                ),
              ),
              _searchButton(controller, homeState),
              _rightButton(context, controller, eventState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    HomeController controller,
    HomePageState homeState,
    HomeConnectionViewPageState connection,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _connectionSummary(context, controller, connection),
          Divider(height: 1, color: ColorManager.border(context)),
          Expanded(
            child: HomeNodePanel(showSearch: homeState.nodeSearchVisible),
          ),
        ],
      ),
    );
  }

  Widget _connectionSummary(
    BuildContext context,
    HomeController controller,
    HomeConnectionViewPageState connection,
  ) {
    final xrayProfileName = context.select<HomeController, String>(
      (controller) => controller.state.xrayProfileName,
    );
    return HomeConnectionSummary(
      connection: connection,
      xrayProfileName: xrayProfileName,
      onToggleConnection: controller.startVpn,
      onShowNodeInfo: controller.gotoNodeInfo,
      onShowXrayProfile: controller.gotoXrayProfile,
    );
  }

  Widget _rightButton(
    BuildContext context,
    HomeController controller,
    AppEventBusState eventState,
  ) {
    if (eventState.downloading) {
      return CircularProgressIndicator();
    } else {
      return HomeAddMenuButton(onSelected: controller.addMenuAction);
    }
  }

  Widget _searchButton(HomeController controller, HomePageState homeState) {
    return IconButton(
      onPressed: controller.toggleNodeSearch,
      icon: Icon(homeState.nodeSearchVisible ? Icons.close : Icons.search),
    );
  }
}

class HomeAddMenuButton extends StatelessWidget {
  const HomeAddMenuButton({super.key, required this.onSelected});

  final ValueChanged<HomeAddMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return AppMenuButton<HomeAddMenuAction>(
      icon: Icons.add,
      entries: [
        AppMenuEntry<HomeAddMenuAction>.submenu(
          title: IconMenuId.manualInput.title,
          icon: IconMenuId.manualInput.icon,
          children: [
            AppMenuEntry<HomeAddMenuAction>.item(
              value: HomeAddMenuAction.manualOutbound,
              title: localizations.homeManualInputOutbound,
              icon: Icons.hub_outlined,
            ),
            AppMenuEntry<HomeAddMenuAction>.item(
              value: HomeAddMenuAction.manualFull,
              title: localizations.homeManualInputFullConfig,
              icon: Icons.schema_outlined,
            ),
            AppMenuEntry<HomeAddMenuAction>.item(
              value: HomeAddMenuAction.manualRaw,
              title: localizations.homeManualInputRawJson,
              icon: Icons.data_object,
            ),
          ],
        ),
        _menuItem(IconMenuId.subscribeLink, HomeAddMenuAction.subscribeLink),
        if (AppPlatform.isMobile)
          _menuItem(IconMenuId.scanQRCode, HomeAddMenuAction.scanQRCode),
        _menuItem(IconMenuId.pickImage, HomeAddMenuAction.pickImage),
        _menuItem(IconMenuId.pickFile, HomeAddMenuAction.pickFile),
        _menuItem(IconMenuId.readPasteboard, HomeAddMenuAction.readPasteboard),
      ],
      onSelected: onSelected,
    );
  }

  AppMenuEntry<HomeAddMenuAction> _menuItem(
    IconMenuId menu,
    HomeAddMenuAction action,
  ) {
    return AppMenuEntry<HomeAddMenuAction>.item(
      value: action,
      title: menu.title,
      icon: menu.icon,
    );
  }
}

class HomeNodePanel extends StatelessWidget {
  const HomeNodePanel({super.key, required this.showSearch});

  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    final selectedId = context.select<HomeController, int>(
      (controller) => controller.state.configId,
    );
    return Material(
      color: ColorManager.surface(context),
      child: HomeNodeView(
        queryType: HomeNodeQueryType.homeNodes,
        showSearch: showSearch,
        selectedId: selectedId,
        onSelect: (config) =>
            context.read<HomeController>().updateConfigId(config.id),
      ),
    );
  }
}

class HomeConnectionSummary extends StatelessWidget {
  const HomeConnectionSummary({
    super.key,
    required this.connection,
    required this.xrayProfileName,
    required this.onToggleConnection,
    required this.onShowNodeInfo,
    required this.onShowXrayProfile,
  });

  final HomeConnectionViewPageState connection;
  final String xrayProfileName;
  final VoidCallback onToggleConnection;
  final VoidCallback onShowNodeInfo;
  final VoidCallback onShowXrayProfile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorManager.surface(context),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wideLayout = constraints.maxWidth >= 720;
            final status = _statusSummary(context);
            final metrics = _metrics(context);
            if (wideLayout) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 4, child: status),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: metrics),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [status, const SizedBox(height: 10), metrics],
            );
          },
        ),
      ),
    );
  }

  Widget _statusSummary(BuildContext context) {
    final summaryDetailText = connection.summaryDetailText;
    final borderRadius = BorderRadius.circular(8);
    return Tooltip(
      message: connection.statusText,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: connection.loading ? null : onToggleConnection,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            child: Row(
              children: [
                _actionIndicator(context),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: ColorManager.primaryText(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        connection.nodeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorManager.primaryText(context),
                        ),
                      ),
                      if (summaryDetailText != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          summaryDetailText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorManager.secondaryText(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionIndicator(BuildContext context) {
    final accentColor = _accentColor(context);
    final backgroundColor = connection.tone == HomeConnectionTone.disconnected
        ? ColorManager.buttonStop(context)
        : accentColor;
    final foregroundColor = switch (connection.tone) {
      HomeConnectionTone.disconnected => ColorManager.buttonStopForeground(
        context,
      ),
      HomeConnectionTone.failed => Theme.of(context).colorScheme.onError,
      _ => Theme.of(context).colorScheme.onPrimary,
    };
    final child = connection.loading
        ? SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(
              color: foregroundColor,
              strokeWidth: 3,
            ),
          )
        : Icon(connection.actionIcon, size: 30);
    return SizedBox.square(
      dimension: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: foregroundColor),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _metrics(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 4, child: _xrayProfileBar(context)),
        const SizedBox(width: 10),
        Expanded(flex: 6, child: _metricBar(context)),
      ],
    );
  }

  Widget _xrayProfileBar(BuildContext context) {
    return Tooltip(
      message: xrayProfileName,
      child: _summaryBar(
        context,
        icon: Icons.tune,
        title: AppLocalizations.of(context)!.homeOutboundViewXrayProfile,
        subtitle: xrayProfileName,
        onTap: onShowXrayProfile,
      ),
    );
  }

  Widget _metricBar(BuildContext context) {
    return _summaryBar(
      context,
      icon: Icons.swap_vert,
      title: connection.trafficText,
      subtitle: connection.metricsText,
      onTap: onShowNodeInfo,
    );
  }

  Widget _summaryBar(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final borderRadius = BorderRadiusDirectional.circular(8);
    return Material(
      color: ColorManager.tagBackground(context),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: ColorManager.border(context)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: ColorManager.secondaryText(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.1,
                        color: ColorManager.primaryText(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.1,
                        color: ColorManager.secondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: ColorManager.secondaryText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentColor(BuildContext context) {
    switch (connection.tone) {
      case HomeConnectionTone.connected:
      case HomeConnectionTone.connecting:
      case HomeConnectionTone.waitingForApproval:
        return Theme.of(context).colorScheme.primary;
      case HomeConnectionTone.failed:
        return Theme.of(context).colorScheme.error;
      case HomeConnectionTone.disconnected:
        return ColorManager.secondaryText(context);
    }
  }
}
