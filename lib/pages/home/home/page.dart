import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/home/component/outbound/controller.dart';
import 'package:onexray/pages/home/home/component/outbound/view.dart';
import 'package:onexray/pages/home/home/component/raw/controller.dart';
import 'package:onexray/pages/home/home/component/raw/view.dart';
import 'package:onexray/pages/home/home/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.initialWorkspace = HomeWorkspace.connection,
    this.initialTabIndex = 0,
  });

  final HomeWorkspace initialWorkspace;
  final int initialTabIndex;

  static const double _adaptiveBreakpoint = 840;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                HomeController(context, initialWorkspace: initialWorkspace),
          ),
          BlocProvider(create: (_) => HomeOutboundController()),
          BlocProvider(create: (_) => HomeRawController()),
        ],
        child: BlocBuilder<HomeController, HomeState>(
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
                    connection,
                    eventState,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _compactScaffold(
    BuildContext context,
    HomeController controller,
    HomeConnectionViewState connection,
    AppEventBusState eventState,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.homePageTitle),
        actions: [
          _searchButton(context),
          _rightButton(context, controller, eventState),
        ],
      ),
      body: SafeArea(child: _body(context, controller, connection)),
    );
  }

  Widget _adaptiveScaffold(
    BuildContext context,
    HomeController controller,
    HomeState homeState,
    HomeConnectionViewState connection,
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
    HomeState homeState,
    HomeConnectionViewState connection,
    AppEventBusState eventState,
  ) {
    if (homeState.workspace == HomeWorkspace.nodes) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _adaptiveHeader(
            context,
            controller,
            eventState,
            title: AppLocalizations.of(context)!.homePageTabOutbound,
          ),
          Expanded(
            child: _configSwitcherPanel(context, controller, showHeader: false),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _adaptiveHeader(context, controller, eventState),
        HomeConnectionSummary(
          connection: connection,
          onToggleConnection: () => controller.startVpn(context),
          onShowNodeInfo: () => controller.gotoNodeInfo(context),
        ),
        Divider(height: 1, color: ColorManager.border(context)),
        Expanded(
          child: _configSwitcherPanel(context, controller, showHeader: false),
        ),
      ],
    );
  }

  Widget _adaptiveHeader(
    BuildContext context,
    HomeController controller,
    AppEventBusState eventState, {
    String? title,
  }) {
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
                  title ?? AppLocalizations.of(context)!.homePageTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ColorManager.primaryText(context),
                  ),
                ),
              ),
              _searchButton(context),
              _rightButton(context, controller, eventState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _configSwitcherPanel(
    BuildContext context,
    HomeController controller, {
    required bool showHeader,
  }) {
    return Material(
      color: ColorManager.surface(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) _configSwitcherHeader(context),
          _tabBar(context, controller),
          Expanded(child: _tabBarView(context, controller)),
        ],
      ),
    );
  }

  Widget _configSwitcherHeader(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            AppLocalizations.of(context)!.homePageCurrentNode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ColorManager.primaryText(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    HomeController controller,
    HomeConnectionViewState connection,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeConnectionSummary(
            connection: connection,
            onToggleConnection: () => controller.startVpn(context),
            onShowNodeInfo: () => controller.gotoNodeInfo(context),
          ),
          Divider(height: 1, color: ColorManager.border(context)),
          Expanded(
            child: _configSwitcherPanel(context, controller, showHeader: false),
          ),
        ],
      ),
    );
  }

  Widget _searchButton(BuildContext context) {
    final tabController = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: tabController,
      builder: (context, child) {
        if (tabController.index == 0) {
          return BlocBuilder<HomeOutboundController, HomeOutboundState>(
            buildWhen: (previous, current) =>
                previous.searching != current.searching,
            builder: (context, state) {
              return IconButton(
                onPressed: () =>
                    context.read<HomeOutboundController>().toggleSearch(),
                icon: Icon(state.searching ? Icons.close : Icons.search),
              );
            },
          );
        }
        return BlocBuilder<HomeRawController, HomeRawState>(
          buildWhen: (previous, current) =>
              previous.searching != current.searching,
          builder: (context, state) {
            return IconButton(
              onPressed: () => context.read<HomeRawController>().toggleSearch(),
              icon: Icon(state.searching ? Icons.close : Icons.search),
            );
          },
        );
      },
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
      return IconMenuPicker(
        icon: Icons.add,
        menus: [
          IconMenuId.manualInput,
          IconMenuId.subscribeLink,
          if (AppPlatform.isMobile) IconMenuId.scanQRCode,
          IconMenuId.pickImage,
          IconMenuId.pickFile,
          IconMenuId.readPasteboard,
        ],
        callback: (actionId) => controller.addMenuAction(
          context,
          actionId,
          DefaultTabController.of(context).index,
        ),
      );
    }
  }

  Widget _tabBar(BuildContext context, HomeController controller) {
    return ColoredBox(
      color: ColorManager.surface(context),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(text: AppLocalizations.of(context)!.homePageTabOutbound),
          Tab(text: AppLocalizations.of(context)!.homePageTabRaw),
        ],
      ),
    );
  }

  Widget _tabBarView(BuildContext context, HomeController controller) {
    return TabBarView(children: const [HomeOutboundView(), HomeRawView()]);
  }
}

class HomeConnectionSummary extends StatelessWidget {
  const HomeConnectionSummary({
    super.key,
    required this.connection,
    required this.onToggleConnection,
    required this.onShowNodeInfo,
  });

  final HomeConnectionViewState connection;
  final VoidCallback onToggleConnection;
  final VoidCallback onShowNodeInfo;

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
              final metricsWidth = (constraints.maxWidth * 0.46).clamp(
                460.0,
                620.0,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 320),
                      child: status,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: metricsWidth),
                    child: metrics,
                  ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 340;
        final traffic = _metric(
          context,
          icon: Icons.swap_vert,
          label: AppLocalizations.of(context)!.nodeInfoPageTraffic,
          value: connection.trafficText,
        );
        final location = _metric(
          context,
          icon: Icons.location_on_outlined,
          label: AppLocalizations.of(context)!.nodeInfoPageLocation,
          value: connection.detailText,
        );
        if (stacked) {
          return Column(
            children: [traffic, const SizedBox(height: 8), location],
          );
        }
        return Row(
          children: [
            Expanded(child: traffic),
            const SizedBox(width: 8),
            Expanded(child: location),
          ],
        );
      },
    );
  }

  Widget _metric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final borderRadius = BorderRadiusDirectional.circular(8);
    return Material(
      color: ColorManager.tagBackground(context),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onShowNodeInfo,
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
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorManager.secondaryText(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.1,
                        color: ColorManager.primaryText(context),
                      ),
                    ),
                  ],
                ),
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
