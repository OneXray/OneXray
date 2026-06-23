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
  static const double _inspectorBreakpoint = 1060;
  static const double _inspectorWidth = 320;
  static const double _largeInspectorWidth = 360;

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
                      constraints,
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
        leading: IconButton(
          onPressed: () => controller.gotoSettings(context),
          icon: const Icon(Icons.settings),
        ),
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
    BoxConstraints constraints,
  ) {
    final inNodesWorkspace = homeState.workspace == HomeWorkspace.nodes;
    final showSwitcher =
        !inNodesWorkspace && constraints.maxWidth >= _inspectorBreakpoint;
    final inspectorWidth = constraints.maxWidth >= 1260
        ? _largeInspectorWidth
        : _inspectorWidth;
    return Scaffold(
      body: SafeArea(
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _adaptivePrimary(
                  context,
                  controller,
                  homeState,
                  connection,
                  eventState,
                  showSwitcher,
                ),
              ),
              if (showSwitcher) ...[
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: ColorManager.border(context),
                ),
                SizedBox(
                  width: inspectorWidth,
                  child: _configSwitcherPanel(
                    context,
                    controller,
                    showHeader: true,
                  ),
                ),
              ],
            ],
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
    bool showSwitcher,
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
        Expanded(
          child: showSwitcher
              ? _connectionDashboard(
                  context,
                  controller,
                  connection,
                  expanded: true,
                )
              : _adaptiveStackedHome(context, controller, connection),
        ),
      ],
    );
  }

  Widget _adaptiveStackedHome(
    BuildContext context,
    HomeController controller,
    HomeConnectionViewState connection,
  ) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: _connectionDashboard(
            context,
            controller,
            connection,
            expanded: true,
          ),
        ),
        Divider(height: 1, color: ColorManager.border(context)),
        Expanded(
          flex: 4,
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

  Widget _connectionDashboard(
    BuildContext context,
    HomeController controller,
    HomeConnectionViewState connection, {
    required bool expanded,
  }) {
    if (!expanded) {
      return Material(
        color: ColorManager.surface(context),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 22),
          child: _connectionDashboardContent(
            context,
            controller,
            connection,
            expanded: false,
          ),
        ),
      );
    }
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minHeight = constraints.maxHeight > 64
              ? constraints.maxHeight - 64
              : 0.0;
          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 32,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: _connectionDashboardContent(
                    context,
                    controller,
                    connection,
                    expanded: true,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _connectionDashboardContent(
    BuildContext context,
    HomeController controller,
    HomeConnectionViewState connection, {
    required bool expanded,
  }) {
    final titleFontSize = expanded ? 34.0 : 28.0;
    final detailMaxLines = expanded ? 3 : 2;
    return Column(
      mainAxisSize: expanded ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _primaryVpnButton(context, controller, connection, expanded: expanded),
        SizedBox(height: expanded ? 24 : 18),
        Text(
          connection.statusText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w800,
            color: ColorManager.primaryText(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          connection.detailText,
          maxLines: detailMaxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: ColorManager.secondaryText(context),
          ),
        ),
        SizedBox(height: expanded ? 28 : 20),
        _currentNodeSummary(context, connection),
        if (connection.connected) ...[
          SizedBox(height: expanded ? 18 : 14),
          _connectionMetrics(
            context,
            controller,
            connection,
            expanded: expanded,
          ),
        ],
      ],
    );
  }

  Widget _primaryVpnButton(
    BuildContext context,
    HomeController controller,
    HomeConnectionViewState connection, {
    required bool expanded,
  }) {
    final dimension = expanded ? 144.0 : 116.0;
    final accentColor = _connectionAccentColor(context, connection);
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
            dimension: expanded ? 42 : 34,
            child: CircularProgressIndicator(color: accentColor),
          )
        : Icon(connection.actionIcon, size: expanded ? 58 : 46);
    final button = SizedBox.square(
      dimension: dimension,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsetsDirectional.zero,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          iconColor: foregroundColor,
          elevation: 0,
          shape: const CircleBorder(),
        ),
        onPressed: connection.loading
            ? null
            : () => controller.startVpn(context),
        child: child,
      ),
    );
    return Tooltip(message: connection.statusText, child: button);
  }

  Widget _currentNodeSummary(
    BuildContext context,
    HomeConnectionViewState connection,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadiusDirectional.circular(8),
        border: Border.all(color: ColorManager.border(context)),
        color: ColorManager.surface(context),
      ),
      child: Row(
        children: [
          Icon(
            connection.statusIcon,
            size: 22,
            color: _connectionAccentColor(context, connection),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.homePageCurrentNode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorManager.secondaryText(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  connection.nodeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorManager.primaryText(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectionMetrics(
    BuildContext context,
    HomeController controller,
    HomeConnectionViewState connection, {
    required bool expanded,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactMetricWidth = (constraints.maxWidth - 12) / 2;
        final metricWidth = expanded
            ? 260.0
            : compactMetricWidth < 120
            ? constraints.maxWidth
            : compactMetricWidth;
        return Wrap(
          alignment: WrapAlignment.center,
          runSpacing: 12,
          spacing: 12,
          children: [
            _connectionMetric(
              context,
              Icons.swap_vert,
              AppLocalizations.of(context)!.nodeInfoPageTraffic,
              connection.trafficText,
              metricWidth,
              onTap: () => controller.gotoNodeInfo(context),
            ),
            _connectionMetric(
              context,
              Icons.location_on_outlined,
              AppLocalizations.of(context)!.nodeInfoPageLocation,
              connection.detailText,
              metricWidth,
              onTap: () => controller.gotoNodeInfo(context),
            ),
          ],
        );
      },
    );
  }

  Widget _connectionMetric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    double width, {
    VoidCallback? onTap,
  }) {
    final borderRadius = BorderRadiusDirectional.circular(8);
    return SizedBox(
      width: width,
      child: Material(
        color: ColorManager.surface(context),
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsetsDirectional.all(12),
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: ColorManager.border(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: ColorManager.secondaryText(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorManager.secondaryText(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.25,
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
      ),
    );
  }

  Color _connectionAccentColor(
    BuildContext context,
    HomeConnectionViewState connection,
  ) {
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
          _connectionDashboard(
            context,
            controller,
            connection,
            expanded: false,
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
