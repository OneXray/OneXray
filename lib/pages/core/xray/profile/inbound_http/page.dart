import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/inbound_http/controller.dart';
import 'package:onexray/pages/core/xray/profile/inbound_http/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class InboundHttpPage extends StatelessWidget {
  final InboundHttpParams params;

  const InboundHttpPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboundHttpController(params),
      child: BlocBuilder<InboundHttpController, InboundHttpPageState>(
        builder: (context, state) {
          final controller = context.read<InboundHttpController>();
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.inboundHttpPageTitle,
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
    InboundHttpController controller,
    InboundHttpPageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.inboundHttpPageTitle,
      children: [
        SelectSettingRow<String>(
          leading: const Icon(LucideIcons.ear),
          title: localizations.inboundProxyPageListen,
          value: state.httpState.listen,
          displayValue: _listenDisplay(context, state.httpState.listen),
          selections: InboundHttpState.listenValues,
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
          value: state.httpState.protocol.name,
        ),
        SettingRow(
          leading: const Icon(LucideIcons.tag),
          title: localizations.inboundProxyPageTag,
          value: state.httpState.tag.name,
        ),
      ],
    );
  }

  Widget _authSection(BuildContext context, InboundHttpController controller) {
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
