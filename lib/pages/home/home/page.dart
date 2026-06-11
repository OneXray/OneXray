import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/app_update/reminder.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => HomeController(context, _tabController)),
        BlocProvider(create: (_) => HomeOutboundController()),
        BlocProvider(create: (_) => HomeRawController()),
      ],
      child: BlocBuilder<HomeController, HomeState>(
        builder: (context, homeState) {
          final controller = context.read<HomeController>();
          return BlocBuilder<AppEventBus, AppEventBusState>(
            builder: (context, eventState) => AppUpdateReminder(
              child: Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    onPressed: () => controller.gotoSettings(context),
                    icon: Icon(Icons.settings),
                  ),
                  title: Text(AppLocalizations.of(context)!.homePageTitle),
                  actions: [
                    _searchButton(context),
                    _rightButton(context, controller, eventState),
                  ],
                ),
                body: SafeArea(
                  child: _body(context, controller, homeState, eventState),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _searchButton(BuildContext context) {
    if (_tabController.index == 0) {
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
      buildWhen: (previous, current) => previous.searching != current.searching,
      builder: (context, state) {
        return IconButton(
          onPressed: () => context.read<HomeRawController>().toggleSearch(),
          icon: Icon(state.searching ? Icons.close : Icons.search),
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
        callback: (actionId) => controller.addMenuAction(context, actionId),
      );
    }
  }

  Widget _body(
    BuildContext context,
    HomeController controller,
    HomeState homeState,
    AppEventBusState eventState,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tabBar(context, controller),
          Expanded(child: _tabBarView(context, controller)),
          _bottomButton(context, controller, homeState, eventState),
        ],
      ),
    );
  }

  Widget _tabBar(BuildContext context, HomeController controller) {
    return ColoredBox(
      color: ColorManager.surface(context),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(text: AppLocalizations.of(context)!.homePageTabOutbound),
          Tab(text: AppLocalizations.of(context)!.homePageTabRaw),
        ],
      ),
    );
  }

  Widget _tabBarView(BuildContext context, HomeController controller) {
    return TabBarView(
      controller: _tabController,
      children: const [HomeOutboundView(), HomeRawView()],
    );
  }

  Widget _bottomButton(
    BuildContext context,
    HomeController controller,
    HomeState homeState,
    AppEventBusState eventState,
  ) {
    return Container(
      color: ColorManager.surface(context),
      padding: EdgeInsetsDirectional.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _connectionInfo(
                  context,
                  controller,
                  homeState,
                  eventState,
                ),
              ),
              _startVpnButton(context, controller, eventState),
            ],
          ),
        ],
      ),
    );
  }

  Widget _startVpnButton(
    BuildContext context,
    HomeController controller,
    AppEventBusState eventState,
  ) {
    if (eventState.vpnLoading) {
      return const SizedBox.square(
        dimension: 56,
        child: Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    } else {
      final disconnected = eventState.runningId == DBConstants.defaultId;
      final color = disconnected
          ? ColorManager.buttonStop(context)
          : Theme.of(context).colorScheme.primary;
      final foregroundColor = disconnected
          ? ColorManager.buttonStopForeground(context)
          : Theme.of(context).colorScheme.onPrimary;
      final icon = disconnected ? Icons.public : Icons.private_connectivity;
      final style = ElevatedButton.styleFrom(
        padding: EdgeInsetsDirectional.zero,
        backgroundColor: color,
        iconSize: 30,
        iconColor: foregroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusDirectional.circular(12),
        ),
      );
      return SizedBox(
        width: 56,
        height: 56,
        child: ElevatedButton(
          style: style,
          onPressed: () => controller.startVpn(context),
          child: Icon(icon),
        ),
      );
    }
  }

  Widget _connectionInfo(
    BuildContext context,
    HomeController controller,
    HomeState homeState,
    AppEventBusState eventState,
  ) {
    final connected = eventState.runningId != DBConstants.defaultId;
    final statusText = _statusText(context, eventState, connected);
    final nodeName = homeState.configName.isEmpty
        ? AppLocalizations.of(context)!.homePageNoSelectedNode
        : homeState.configName;
    final detailText = connected
        ? controller.formatGeoLocation(context, eventState.location)
        : "${AppLocalizations.of(context)!.homePageCurrentNode}: $nodeName";
    final content = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.private_connectivity : Icons.public,
            size: 20,
            color: connected
                ? Theme.of(context).colorScheme.primary
                : ColorManager.secondaryText(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: ColorManager.primaryText(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detailText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorManager.secondaryText(context),
                  ),
                ),
              ],
            ),
          ),
          if (connected) const Icon(Icons.chevron_right),
        ],
      ),
    );
    if (!connected) {
      return content;
    }
    return InkWell(
      onTap: () => controller.gotoNodeInfo(context),
      child: content,
    );
  }

  String _statusText(
    BuildContext context,
    AppEventBusState eventState,
    bool connected,
  ) {
    if (eventState.vpnLoading) {
      return AppLocalizations.of(context)!.homePageStatusConnecting;
    }
    if (connected) {
      return AppLocalizations.of(context)!.homePageStatusConnected;
    }
    return AppLocalizations.of(context)!.homePageStatusDisconnected;
  }
}
