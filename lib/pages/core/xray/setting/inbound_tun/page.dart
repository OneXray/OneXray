import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/xray/setting/inbound_tun/controller.dart';
import 'package:onexray/pages/core/xray/setting/inbound_tun/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class InboundTunPage extends StatelessWidget {
  final InboundTunParams params;

  const InboundTunPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboundTunController(params),
      child: BlocBuilder<InboundTunController, InboundTunCubitState>(
        builder: (context, state) {
          final controller = context.read<InboundTunController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.inboundTunPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    InboundTunController controller,
    InboundTunCubitState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _listenSection(context, controller, state),
                    _settingsSection(context, controller, state),
                    _tagSection(context, controller, state),
                    _sniffingSection(context, controller),
                  ],
                ),
              ),
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _listenSection(
    BuildContext context,
    InboundTunController controller,
    InboundTunCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.inboundTunPageListen,
          value: state.tunState.listen,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.inboundTunPageProtocol,
          value: state.tunState.protocol.name,
        ),
      ],
    );
  }

  Widget _settingsSection(
    BuildContext context,
    InboundTunController controller,
    InboundTunCubitState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.inboundTunPageSettings,
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.inboundTunPageSettingsName,
          value: state.tunState.settings.name,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.inboundTunPageSettingsMTU,
          value: "${state.tunState.settings.mtu}",
        ),
        if (AppPlatform.isWindows || AppPlatform.isLinux)
          SettingRow(
            title: AppLocalizations.of(context)!.inboundTunPageSettingsGateway,
            value: _formatList(state.tunState.settings.gateway),
            valueMaxLines: 3,
          ),
        if (AppPlatform.isWindows || AppPlatform.isLinux)
          SettingRow(
            title: AppLocalizations.of(context)!.inboundTunPageSettingsDns,
            value: _formatList(state.tunState.settings.dns),
            valueMaxLines: 3,
          ),
        if (AppPlatform.isWindows || AppPlatform.isLinux)
          SettingRow(
            title: AppLocalizations.of(
              context,
            )!.inboundTunPageSettingsAutoSystemRoutingTable,
            value: _formatList(state.tunState.settings.autoSystemRoutingTable),
            valueMaxLines: 3,
          ),
        if (AppPlatform.isWindows || AppPlatform.isLinux)
          SettingRow(
            title: AppLocalizations.of(
              context,
            )!.inboundTunPageSettingsAutoOutboundsInterface,
            value: state.tunState.settings.autoOutboundsInterface,
          ),
      ],
    );
  }

  String _formatList(List<String> values) {
    return values.join(", ");
  }

  Widget _tagSection(
    BuildContext context,
    InboundTunController controller,
    InboundTunCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.inboundTunPageTag,
          value: state.tunState.tag.name,
        ),
      ],
    );
  }

  Widget _sniffingSection(
    BuildContext context,
    InboundTunController controller,
  ) {
    return SettingSection(
      title: "",
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.inboundTunPageSniffing,
          onTap: () => controller.editSniffing(context),
        ),
      ],
    );
  }

  Widget _bottomButton(BuildContext context, InboundTunController controller) {
    return BottomView(
      child: Row(
        children: [
          Expanded(
            child: PrimaryBottomButton(
              title: AppLocalizations.of(context)!.buttonSave,
              callback: () => controller.save(context),
            ),
          ),
        ],
      ),
    );
  }
}
