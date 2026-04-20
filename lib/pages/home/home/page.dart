import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/home/component/outbound/view.dart';
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
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeController(context, _tabController),
      child: BlocBuilder<HomeController, HomeState>(
        builder: (context, homeState) {
          final controller = context.read<HomeController>();
          return BlocBuilder<AppEventBus, AppEventBusState>(
            builder: (context, eventState) => Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  onPressed: () => controller.gotoSettings(context),
                  icon: Icon(Icons.settings),
                ),
                title: Text(AppLocalizations.of(context)!.homePageTitle),
                actions: [
                  _rightButton(context, controller, eventState),
                ],
              ),
              body: SafeArea(
                child: _body(context, controller, homeState, eventState),
              ),
            ),
          );
        },
      ),
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
              Expanded(child: _nodeInfo(context, controller, eventState)),
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
      return const CircularProgressIndicator();
    } else {
      final stop = eventState.runningId == DBConstants.defaultId;
      final color = stop
          ? ColorManager.buttonStop(context)
          : Theme.of(context).primaryColor;
      final icon = stop ? Icons.public : Icons.private_connectivity;
      final style = ElevatedButton.styleFrom(
        padding: EdgeInsetsDirectional.zero,
        backgroundColor: color,
        iconSize: 30,
        iconColor: Colors.white,
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

  Widget _nodeInfo(
    BuildContext context,
    HomeController controller,
    AppEventBusState eventState,
  ) {
    if (eventState.runningId == DBConstants.defaultId) {
      return SizedBox(height: 1);
    } else {
      final location = eventState.location;
      final text = controller.formatGeoLocation(context, location);
      return InkWell(
        onTap: () => controller.gotoNodeInfo(context),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: ColorManager.primaryText(context),
                  ),
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
    }
  }
}
