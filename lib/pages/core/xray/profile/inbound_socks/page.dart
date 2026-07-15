import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/inbound_socks/controller.dart';
import 'package:onexray/pages/core/xray/profile/inbound_socks/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class InboundSocksPage extends StatelessWidget {
  final InboundSocksParams params;

  const InboundSocksPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboundSocksController(params),
      child: BlocBuilder<InboundSocksController, InboundSocksPageState>(
        builder: (context, state) {
          final controller = context.read<InboundSocksController>();
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.inboundSocksPageTitle,
            onSave: () => controller.save(context),
            body: SettingsPageScroll(
              desktopMaxWidth: 900,
              child: SettingsResponsiveColumns(
                firstFlex: 6,
                secondFlex: 4,
                first: [_identitySection(context, controller, state)],
                second: [_authSection(context, controller)],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _identitySection(
    BuildContext context,
    InboundSocksController controller,
    InboundSocksPageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.inboundSocksPageTitle,
      children: [
        SelectSettingRow<String>(
          leading: const Icon(LucideIcons.ear),
          title: localizations.inboundProxyPageListen,
          value: state.socksState.listen,
          displayValue: _listenDisplay(context, state.socksState.listen),
          selections: InboundSocksState.listenValues,
          titleBuilder: (value) => _listenDisplay(context, value),
          onSelected: controller.updateListen,
        ),
        TextFieldSettingRow(
          controller: controller.portController,
          label: localizations.inboundProxyPagePort,
          keyboardType: TextInputType.number,
        ),
        SettingRow(
          leading: const Icon(LucideIcons.waypoints),
          title: localizations.inboundProxyPageProtocol,
          value: state.socksState.protocol.name,
        ),
        SettingRow(
          leading: const Icon(LucideIcons.radio),
          title: localizations.inboundProxyPageUdp,
          value: localizations.switchEnabled,
        ),
        SettingRow(
          leading: const Icon(LucideIcons.tag),
          title: localizations.inboundProxyPageTag,
          value: state.socksState.tag.name,
        ),
      ],
    );
  }

  Widget _authSection(BuildContext context, InboundSocksController controller) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.inboundProxyPageAuth,
      children: [
        TextFieldSettingRow(
          controller: controller.userController,
          label: localizations.inboundProxyPageUser,
        ),
        TextFieldSettingRow(
          controller: controller.passController,
          label: localizations.inboundProxyPagePass,
        ),
      ],
    );
  }

  String _listenDisplay(BuildContext context, String listen) {
    if (listen.isEmpty) {
      return AppLocalizations.of(context)!.inboundProxyPageAllInterfaces;
    }
    return listen;
  }
}
