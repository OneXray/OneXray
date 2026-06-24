import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:onexray/service/xray/metrics/formatter.dart';

class NodeInfoPage extends StatelessWidget {
  const NodeInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.nodeInfoPageTitle),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.menuRefresh,
            onPressed: () => VpnService().retryConnectivityTest(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: const SafeArea(child: NodeInfoContent()),
    );
  }
}

class NodeInfoContent extends StatelessWidget {
  const NodeInfoContent({super.key});

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
                builder: (context, state) => _section(context, state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, AppEventBusState state) {
    final appLocalizations = AppLocalizations.of(context)!;
    final location = state.location;
    final duration = location.duration ?? appLocalizations.nodeInfoPageFetching;
    final delay = _delayValue(context, state);
    final traffic = XrayMetricsFormatter.formatTraffic(state.trafficMetrics);
    final ipAddress = _geoValue(context, state, location.ipAddress);
    final ipVersion = _geoValue(context, state, location.ipVersion);
    final country = _geoValue(context, state, location.country);
    final region = _geoValue(context, state, location.region);
    final city = _geoValue(context, state, location.city);

    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageDuration,
          value: duration,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageDelay,
          value: delay,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageTraffic,
          value: traffic,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageIP,
          value: ipAddress,
          valueMaxLines: 4,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageIPVersion,
          value: ipVersion,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageCountryOrRegion,
          value: country,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageRegion,
          value: region,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.nodeInfoPageCity,
          value: city,
        ),
      ],
    );
  }

  String _delayValue(BuildContext context, AppEventBusState state) {
    final appLocalizations = AppLocalizations.of(context)!;
    switch (state.pingProbeState) {
      case ConnectivityProbeState.idle:
      case ConnectivityProbeState.loading:
        return appLocalizations.nodeInfoPageFetching;
      case ConnectivityProbeState.failed:
        return appLocalizations.nodeInfoPageFailed;
      case ConnectivityProbeState.success:
        final delay = state.location.delay;
        return delay == null
            ? appLocalizations.nodeInfoPageFailed
            : "${delay}ms";
    }
  }

  String _geoValue(
    BuildContext context,
    AppEventBusState state,
    String? value,
  ) {
    final appLocalizations = AppLocalizations.of(context)!;
    switch (state.geoLocationProbeState) {
      case ConnectivityProbeState.idle:
      case ConnectivityProbeState.loading:
        return appLocalizations.nodeInfoPageFetching;
      case ConnectivityProbeState.failed:
        return appLocalizations.nodeInfoPageFailed;
      case ConnectivityProbeState.success:
        return value ?? appLocalizations.nodeInfoPageFailed;
    }
  }
}
