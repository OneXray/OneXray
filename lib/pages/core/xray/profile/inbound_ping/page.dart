import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/inbound_ping/controller.dart';
import 'package:onexray/pages/core/xray/profile/inbound_ping/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class InboundPingPage extends StatelessWidget {
  final InboundPingParams params;

  const InboundPingPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboundPingController(params),
      child: BlocBuilder<InboundPingController, InboundPingPageState>(
        builder: (context, state) {
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.inboundPingPageTitle,
            body: SettingsPageScroll(
              desktopMaxWidth: 760,
              child: SettingSection(
                title: "",
                children: [
                  SettingRow(
                    leading: const Icon(LucideIcons.ear),
                    title: localizations.inboundPingPageListen,
                    value: state.httpState.listen,
                  ),
                  SettingRow(
                    leading: const Icon(LucideIcons.radioTower),
                    title: localizations.inboundPingPagePort,
                    value: state.httpState.port,
                  ),
                  SettingRow(
                    leading: const Icon(LucideIcons.waypoints),
                    title: localizations.inboundPingPageProtocol,
                    value: state.httpState.protocol.name,
                  ),
                  SettingRow(
                    leading: const Icon(LucideIcons.tag),
                    title: localizations.inboundPingPageTag,
                    value: state.httpState.tag.name,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
