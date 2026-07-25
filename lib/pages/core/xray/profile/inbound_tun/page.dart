import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/inbound_tun/controller.dart';
import 'package:onexray/pages/core/xray/profile/inbound_tun/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class InboundTunPage extends StatelessWidget {
  final InboundTunParams params;

  const InboundTunPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboundTunController(params),
      child: BlocBuilder<InboundTunController, InboundTunPageState>(
        builder: (context, state) {
          final controller = context.read<InboundTunController>();
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.inboundTunPageTitle,
            onSave: () => controller.save(context),
            body: SettingsPageScroll(
              desktopMaxWidth: 900,
              child: SettingsResponsiveColumns(
                firstFlex: 5,
                secondFlex: 5,
                first: [_identitySection(context, state)],
                second: [
                  _settingsSection(context, state),
                  _sniffingSection(context, controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _identitySection(BuildContext context, InboundTunPageState state) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.ear),
          title: localizations.inboundTunPageListen,
          value: state.tunState.listen,
        ),
        SettingRow(
          leading: const Icon(LucideIcons.waypoints),
          title: localizations.inboundTunPageProtocol,
          value: state.tunState.protocol.name,
        ),
        SettingRow(
          leading: const Icon(LucideIcons.tag),
          title: localizations.inboundTunPageTag,
          value: state.tunState.tag.name,
        ),
      ],
    );
  }

  Widget _settingsSection(BuildContext context, InboundTunPageState state) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.inboundTunPageSettings,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.network),
          title: localizations.inboundTunPageSettingsName,
          value: state.tunState.settings.name,
        ),
        SettingRow(
          leading: const Icon(LucideIcons.gauge),
          title: localizations.inboundTunPageSettingsMTU,
          value: '${state.tunState.settings.mtu}',
        ),
        if (AppPlatform.isWindows || AppPlatform.isLinux)
          SettingRow(
            leading: const Icon(LucideIcons.router),
            title: localizations.inboundTunPageSettingsGateway,
            value: _formatList(state.tunState.settings.gateway),
            valueMaxLines: 3,
          ),
        if (AppPlatform.isWindows || AppPlatform.isLinux)
          SettingRow(
            leading: const Icon(LucideIcons.server),
            title: localizations.inboundTunPageSettingsDns,
            value: _formatList(state.tunState.settings.dns),
            valueMaxLines: 3,
          ),
        if (AppPlatform.isWindows || AppPlatform.isLinux)
          SettingRow(
            leading: const Icon(LucideIcons.route),
            title: localizations.inboundTunPageSettingsAutoSystemRoutingTable,
            value: _formatList(state.tunState.settings.autoSystemRoutingTable),
            valueMaxLines: 3,
          ),
        if (AppPlatform.isWindows || AppPlatform.isLinux)
          SettingRow(
            leading: const Icon(LucideIcons.panelTopOpen),
            title: localizations.inboundTunPageSettingsAutoOutboundsInterface,
            value: state.tunState.settings.autoOutboundsInterface,
          ),
      ],
    );
  }

  Widget _sniffingSection(
    BuildContext context,
    InboundTunController controller,
  ) {
    return SettingSection(
      title: '',
      children: [
        NavigationSettingRow(
          leading: const Icon(LucideIcons.scanSearch),
          title: AppLocalizations.of(context)!.inboundTunPageSniffing,
          onTap: () => controller.editSniffing(context),
        ),
      ],
    );
  }

  String _formatList(List<String> values) => values.join(', ');
}
