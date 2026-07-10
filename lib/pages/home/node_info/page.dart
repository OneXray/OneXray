import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/node_info/controller.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class NodeInfoPage extends StatelessWidget {
  const NodeInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = NodeInfoController();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.nodeInfoPageTitle),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.menuRefresh,
            onPressed: controller.retryConnectivityTest,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: NodeInfoContent(controller: controller)),
    );
  }
}

class NodeInfoContent extends StatelessWidget {
  final NodeInfoController controller;

  const NodeInfoContent({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: SingleChildScrollView(
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlocBuilder<AppEventBus, AppEventBusState>(
                builder: (context, state) => _section(
                  context,
                  controller.buildViewState(context, state),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, NodeInfoViewState state) {
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageDuration,
          value: state.duration,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageDelay,
          value: state.delay,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageTraffic,
          value: state.traffic,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageIP,
          value: state.ipAddress,
          valueMaxLines: 4,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageIPVersion,
          value: state.ipVersion,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageCountryOrRegion,
          value: state.country,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageRegion,
          value: state.region,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageCity,
          value: state.city,
        ),
      ],
    );
  }
}
