import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/inbound_additional/controller.dart';
import 'package:onexray/pages/core/xray/profile/inbound_additional/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/additional_inbound_state.dart';
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
            builder: (context, state) {
              final controller = context.read<AdditionalInboundController>();
              return SettingsPageScaffold(
                title: _pageTitle(context, state.inbound.type),
                onSave: () => controller.save(context),
                body: SettingsPageScroll(
                  desktopMaxWidth: 900,
                  child: SettingsResponsiveColumns(
                    firstFlex: 5,
                    secondFlex: 5,
                    first: [
                      _listenerSection(context, controller, state.inbound),
                    ],
                    second: [
                      if (state.inbound is AuthenticatedAdditionalInboundState)
                        _authenticationSection(
                          context,
                          controller,
                          state.inbound as AuthenticatedAdditionalInboundState,
                        ),
                      if (state.inbound is InboundDokodemoDoorState)
                        _targetSection(
                          context,
                          controller,
                          state.inbound as InboundDokodemoDoorState,
                        ),
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
    AdditionalInboundState inbound,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.inboundAdditionalPageSectionListener,
      children: [
        if (inbound is AuthenticatedAdditionalInboundState)
          SelectSettingRow<String>(
            leading: const Icon(LucideIcons.ear),
            title: l10n.inboundTunPageListen,
            subtitle:
                inbound.listen == AdditionalInboundState.allInterfacesListen
                ? l10n.inboundAdditionalPageAllInterfacesWarning
                : null,
            value: inbound.listen,
            displayValue: _listenTitle(context, inbound.listen),
            selections: AdditionalInboundState.listenValues,
            titleBuilder: (value) => _listenTitle(context, value),
            onSelected: controller.updateListen,
          )
        else
          SettingRow(
            leading: const Icon(LucideIcons.ear),
            title: l10n.inboundTunPageListen,
            value: AdditionalInboundState.localListen,
          ),
        SettingRow(
          leading: const Icon(LucideIcons.waypoints),
          title: l10n.inboundTunPageProtocol,
          value: _protocolName(inbound.type),
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
    AdditionalInboundController controller,
    AuthenticatedAdditionalInboundState inbound,
  ) {
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
        if (inbound is InboundSocksState)
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
    InboundDokodemoDoorState inbound,
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
        SelectSettingRow<DokodemoDoorNetwork>(
          leading: const Icon(LucideIcons.route),
          title: l10n.routingRulePageNetwork,
          value: inbound.network.name,
          selections: DokodemoDoorNetwork.values,
          titleBuilder: (value) => value.name,
          onSelected: controller.updateNetwork,
        ),
      ],
    );
  }

  String _pageTitle(BuildContext context, AdditionalInboundType type) {
    final l10n = AppLocalizations.of(context)!;
    return switch (type) {
      AdditionalInboundType.socks => l10n.inboundAdditionalPageSocksTitle,
      AdditionalInboundType.http => l10n.inboundAdditionalPageHttpTitle,
      AdditionalInboundType.dokodemoDoor =>
        l10n.inboundAdditionalPageDokodemoDoorTitle,
    };
  }

  String _listenTitle(BuildContext context, String value) {
    final l10n = AppLocalizations.of(context)!;
    return value == AdditionalInboundState.allInterfacesListen
        ? l10n.inboundAdditionalPageAllInterfaces
        : l10n.inboundAdditionalPageLocalhost;
  }

  String _protocolName(AdditionalInboundType type) {
    return switch (type) {
      AdditionalInboundType.socks => 'socks',
      AdditionalInboundType.http => 'http',
      AdditionalInboundType.dokodemoDoor => 'dokodemo-door',
    };
  }
}
