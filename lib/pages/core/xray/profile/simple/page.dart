import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/simple/controller.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/service/xray/profile/enum.dart';

class XrayProfileSimplePage extends StatelessWidget {
  const XrayProfileSimplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayProfileSimpleController(),
      child:
          BlocBuilder<XrayProfileSimpleController, XrayProfileSimplePageState>(
            builder: (context, state) {
              final controller = context.read<XrayProfileSimpleController>();
              return SettingsPageScaffold(
                title: AppLocalizations.of(context)!.xrayProfileSimplePageTitle,
                onSave: () => controller.save(context),
                body: SettingsPageScroll(
                  child: Column(
                    children: [
                      SettingsPageIntro(
                        title: AppLocalizations.of(
                          context,
                        )!.xrayProfileSimplePageTitle,
                        trailing: SettingsBadge(
                          label: AppLocalizations.of(
                            context,
                          )!.xrayProfileListPageSimple,
                        ),
                      ),
                      SettingsResponsiveColumns(
                        firstFlex: 4,
                        secondFlex: 6,
                        first: [
                          _logSection(context, controller, state),
                          _finalOutboundSection(context, controller, state),
                          _proxySection(context, state),
                        ],
                        second: [
                          _routingSection(context, controller, state),
                          _fakeDnsSection(context, controller, state),
                          _dnsSection(context, state),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _logSection(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.logPageTitle,
      children: [
        SwitchSettingRow(
          leading: const Icon(LucideIcons.fileText),
          title: AppLocalizations.of(context)!.xrayProfileSimplePageEnableLog,
          value: state.xrayProfile.enableLog,
          onChanged: controller.updateEnableLog,
        ),
      ],
    );
  }

  Widget _finalOutboundSection(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    final finalOutboundName = state.finalOutboundName.isEmpty
        ? AppLocalizations.of(context)!.finalOutboundPageDisabled
        : state.finalOutboundName;
    return SettingSection(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageFinalOutbound,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.waypoints),
          title: AppLocalizations.of(
            context,
          )!.xrayProfileSimplePageFinalOutbound,
          value: finalOutboundName,
          onTap: () => controller.editFinalOutbound(context),
          showChevron: state.xrayProfile.finalOutboundId == null,
          trailing: state.xrayProfile.finalOutboundId == null
              ? null
              : IconButton(
                  tooltip: AppLocalizations.of(context)!.buttonCancel,
                  onPressed: controller.clearFinalOutbound,
                  icon: const Icon(LucideIcons.x, size: 17),
                ),
        ),
      ],
    );
  }

  Widget _proxySection(BuildContext context, XrayProfileSimplePageState state) {
    final inbounds = state.inbounds;
    return SettingSection(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageProxy,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.network),
          title: inbounds.socks.tag.name,
          value: _proxyListenPort(
            context,
            inbounds.socks.listen,
            inbounds.socks.port,
          ),
          enabled: false,
        ),
        SettingRow(
          leading: const Icon(LucideIcons.globe2),
          title: inbounds.http.tag.name,
          value: _proxyListenPort(
            context,
            inbounds.http.listen,
            inbounds.http.port,
          ),
          enabled: false,
        ),
      ],
    );
  }

  String _proxyListenPort(BuildContext context, String listen, String port) {
    final listenText = listen.isEmpty
        ? AppLocalizations.of(context)!.inboundProxyPageAllInterfaces
        : listen;
    return "$listenText:$port";
  }

  Widget _routingSection(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageRouting,
      children: [
        SelectSettingRow(
          leading: const Icon(LucideIcons.route),
          title: AppLocalizations.of(
            context,
          )!.xrayProfileSimplePageDomainStrategy,
          value: state.xrayProfile.routing.domainStrategy.name,
          selections: RoutingDomainStrategy.simpleStrategy,
          onSelected: controller.updateDomainStrategy,
        ),
        SelectSettingRow(
          leading: const Icon(LucideIcons.globe2),
          title: AppLocalizations.of(context)!.xrayProfileSimplePageDirectSet,
          value: state.xrayProfile.routing.directSet.name,
          selections: SimpleCountry.names,
          onSelected: controller.updateDirectSet,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.apple),
          title: AppLocalizations.of(context)!.xrayProfileSimplePageAppleDirect,
          value: state.xrayProfile.routing.appleDirect,
          onChanged: controller.updateAppleDirect,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.wifi),
          title: AppLocalizations.of(context)!.xrayProfileSimplePageLocalDirect,
          value: state.xrayProfile.routing.localDirect,
          onChanged: controller.updateLocalDirect,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.ban),
          title: AppLocalizations.of(context)!.xrayProfileSimplePageBlockAds,
          subtitle: "geosite:CATEGORY-ADS-ALL",
          value: state.xrayProfile.routing.blockAds,
          onChanged: controller.updateBlockAds,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.listFilter),
          title: AppLocalizations.of(
            context,
          )!.xrayProfileSimplePageEnableIPRule,
          value: state.xrayProfile.routing.enableIPRule,
          onChanged: controller.updateEnableIPRule,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.database),
          title: AppLocalizations.of(context)!.xrayProfileSimplePageLocalDns,
          value: state.xrayProfile.routing.localDns,
          onChanged: controller.updateLocalDns,
        ),
      ],
    );
  }

  Widget _fakeDnsSection(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.fakeDnsPageTitle,
      children: [
        SwitchSettingRow(
          leading: const Icon(LucideIcons.radioTower),
          title: AppLocalizations.of(context)!.xrayProfileSimplePageFakeDns,
          value: state.xrayProfile.fakeDns,
          onChanged: controller.updateFakeDns,
        ),
      ],
    );
  }

  Widget _dnsSection(BuildContext context, XrayProfileSimplePageState state) {
    return SettingSection(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageDns,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.database),
          title: "tcp://${state.tunDnsIPv4}",
          subtitleWidget: Row(
            children: [TagView(tag: RoutingOutboundTag.proxy.name)],
          ),
        ),
      ],
    );
  }
}
