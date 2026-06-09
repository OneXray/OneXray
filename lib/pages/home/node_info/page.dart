import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class NodeInfoPage extends StatelessWidget {
  const NodeInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.nodeInfoPageTitle),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: SingleChildScrollView(
        child: BlocBuilder<AppEventBus, AppEventBusState>(
          builder: (context, state) => _section(context, state),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, AppEventBusState state) {
    final location = state.location;
    final duration =
        location.duration ?? AppLocalizations.of(context)!.nodeInfoPageFetching;
    var delay = "";
    if (location.delay == null) {
      delay = AppLocalizations.of(context)!.nodeInfoPageFetching;
    } else {
      delay = "${location.delay}ms";
    }
    final ipAddress =
        location.ipAddress ??
        AppLocalizations.of(context)!.nodeInfoPageFetching;
    final ipVersion =
        location.ipVersion ??
        AppLocalizations.of(context)!.nodeInfoPageFetching;
    final country =
        location.country ?? AppLocalizations.of(context)!.nodeInfoPageFetching;
    final region =
        location.region ?? AppLocalizations.of(context)!.nodeInfoPageFetching;
    final city =
        location.city ?? AppLocalizations.of(context)!.nodeInfoPageFetching;

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
}
