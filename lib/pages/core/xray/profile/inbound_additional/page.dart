import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/inbound_additional/controller.dart';
import 'package:onexray/pages/core/xray/profile/inbound_additional/params.dart';
import 'package:onexray/pages/core/xray/profile/inbound_additional/view_data.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AdditionalInboundPage extends StatelessWidget {
  final AdditionalInboundParams params;

  const AdditionalInboundPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdditionalInboundController(params),
      child:
          BlocBuilder<AdditionalInboundController, AdditionalInboundPageState>(
            builder: (context, _) {
              final controller = context.read<AdditionalInboundController>();
              final data = controller.buildViewData(
                AppLocalizations.of(context)!,
              );
              return SettingsPageScaffold(
                title: data.pageTitle,
                onSave: () => controller.save(context),
                body: SettingsPageScroll(
                  desktopMaxWidth: 900,
                  child: SettingsResponsiveColumns(
                    firstFlex: 5,
                    secondFlex: 5,
                    first: [
                      _listenerSection(context, controller, data.listener),
                    ],
                    second: [
                      if (data.showsAuthentication)
                        _authenticationSection(
                          context,
                          controller,
                          showsUdp: data.showsUdp,
                        ),
                      if (data.target case final target?)
                        _targetSection(context, controller, target),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _listenerSection(
    BuildContext context,
    AdditionalInboundController controller,
    AdditionalInboundListenerViewData data,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.inboundAdditionalPageSectionListener,
      children: [
        if (data.editable)
          SelectSettingRow<AdditionalInboundOptionViewData>(
            leading: const Icon(LucideIcons.ear),
            title: l10n.inboundTunPageListen,
            subtitle: data.warning,
            value: data.value,
            displayValue: data.displayValue,
            selections: data.options,
            titleBuilder: (option) => option.title,
            onSelected: (option) => controller.updateListen(option.value),
          )
        else
          SettingRow(
            leading: const Icon(LucideIcons.ear),
            title: l10n.inboundTunPageListen,
            value: data.displayValue,
          ),
        SettingRow(
          leading: const Icon(LucideIcons.waypoints),
          title: l10n.inboundTunPageProtocol,
          value: data.protocolName,
        ),
        TextFieldSettingRow(
          leading: const Icon(LucideIcons.network),
          controller: controller.portController,
          label: l10n.inboundPingPagePort,
          hintText: '11024',
          keyboardType: TextInputType.number,
        ),
        TextFieldSettingRow(
          leading: const Icon(LucideIcons.tag),
          controller: controller.tagController,
          label: l10n.inboundTunPageTag,
          hintText: 'socksIn1',
        ),
      ],
    );
  }

  Widget _authenticationSection(
    BuildContext context,
    AdditionalInboundController controller, {
    required bool showsUdp,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.inboundAdditionalPageSectionAuthentication,
      children: [
        TextFieldSettingRow(
          leading: const Icon(LucideIcons.circleUserRound),
          controller: controller.userController,
          label: l10n.outboundUIPageUser,
          hintText: l10n.outboundUIPageUser,
        ),
        TextFieldSettingRow(
          leading: const Icon(LucideIcons.lockKeyhole),
          controller: controller.passwordController,
          label: l10n.outboundUIPagePassword,
          hintText: l10n.outboundUIPagePassword,
        ),
        if (showsUdp)
          SettingRow(
            leading: const Icon(LucideIcons.radio),
            title: 'UDP',
            value: l10n.switchEnabled,
          ),
      ],
    );
  }

  Widget _targetSection(
    BuildContext context,
    AdditionalInboundController controller,
    AdditionalInboundTargetViewData data,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.inboundAdditionalPageSectionTarget,
      children: [
        TextFieldSettingRow(
          leading: const Icon(LucideIcons.server),
          controller: controller.targetAddressController,
          label: l10n.outboundUIPageAddress,
          hintText: '127.0.0.1',
        ),
        TextFieldSettingRow(
          leading: const Icon(LucideIcons.network),
          controller: controller.targetPortController,
          label: l10n.inboundPingPagePort,
          hintText: '8888',
          keyboardType: TextInputType.number,
        ),
        SelectSettingRow<AdditionalInboundOptionViewData>(
          leading: const Icon(LucideIcons.route),
          title: l10n.routingRulePageNetwork,
          value: data.network,
          selections: data.networkOptions,
          titleBuilder: (option) => option.title,
          onSelected: (option) => controller.updateNetwork(option.value),
        ),
      ],
    );
  }
}
