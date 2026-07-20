import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/dns/view.dart';
import 'package:onexray/pages/core/xray/profile/fake_dns/view.dart';
import 'package:onexray/pages/core/xray/profile/inbounds/view.dart';
import 'package:onexray/pages/core/xray/profile/log/view.dart';
import 'package:onexray/pages/core/xray/profile/outbounds/view.dart';
import 'package:onexray/pages/core/xray/profile/routing/view.dart';
import 'package:onexray/pages/core/xray/profile/ui/controller.dart';
import 'package:onexray/pages/core/xray/profile/ui/params.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class XrayProfileUIPage extends StatelessWidget {
  final XrayProfileUIParams params;

  const XrayProfileUIPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayProfileUIController(params),
      child: BlocBuilder<XrayProfileUIController, XrayProfileUIPageState>(
        builder: (context, state) {
          final controller = context.read<XrayProfileUIController>();
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.xrayProfileUIPageTitle,
            onSave: () => controller.save(context),
            actions: [
              IconButton(
                tooltip: AppLocalizations.of(context)!.menuEdit,
                onPressed: () => controller.gotoRawEdit(context),
                icon: const Icon(LucideIcons.braces),
              ),
            ],
            body: Column(
              children: [
                _nameEditor(context, controller),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 760;
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 224,
                              child: SettingsSectionNavigation(
                                compact: false,
                                selected: state.section,
                                items: _navigationItems(context),
                                onSelected: controller.updateSection,
                              ),
                            ),
                            VerticalDivider(
                              width: 1,
                              color: ColorManager.border(context),
                            ),
                            Expanded(
                              child: _sectionContent(
                                context,
                                controller,
                                state,
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          SettingsSectionNavigation(
                            compact: true,
                            selected: state.section,
                            items: _navigationItems(context),
                            onSelected: controller.updateSection,
                          ),
                          Divider(
                            height: 1,
                            color: ColorManager.border(context),
                          ),
                          Expanded(
                            child: _sectionContent(context, controller, state),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _nameEditor(BuildContext context, XrayProfileUIController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: ColorManager.surface(context),
        border: Border(bottom: BorderSide(color: ColorManager.border(context))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final label = Text(
            AppLocalizations.of(context)!.xrayProfileUIPageName,
            style: AppTypography.navigationLabel,
          );
          final input = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ShadInput(controller: controller.nameController),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [label, const SizedBox(height: 7), input],
            );
          }
          return Row(
            children: [
              SizedBox(width: 132, child: label),
              Expanded(child: input),
            ],
          );
        },
      ),
    );
  }

  List<SettingsSectionNavigationItem<XrayProfileUISection>> _navigationItems(
    BuildContext context,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return [
      SettingsSectionNavigationItem(
        value: XrayProfileUISection.inbounds,
        title: localizations.inboundsPageTitle,
        description: localizations.xrayProfileUIPageInboundsDescription,
        group: localizations.xrayProfileUIPageGroupRuntime,
        icon: LucideIcons.radioTower,
      ),
      SettingsSectionNavigationItem(
        value: XrayProfileUISection.outbounds,
        title: localizations.outboundsPageTitle,
        description: localizations.xrayProfileUIPageOutboundsDescription,
        group: localizations.xrayProfileUIPageGroupRuntime,
        icon: LucideIcons.waypoints,
      ),
      SettingsSectionNavigationItem(
        value: XrayProfileUISection.routing,
        title: localizations.routingPageTitle,
        description: localizations.xrayProfileUIPageRoutingDescription,
        group: localizations.xrayProfileUIPageGroupPolicy,
        icon: LucideIcons.route,
      ),
      SettingsSectionNavigationItem(
        value: XrayProfileUISection.dns,
        title: localizations.dnsPageTitle,
        description: localizations.xrayProfileUIPageDnsDescription,
        group: localizations.xrayProfileUIPageGroupPolicy,
        icon: LucideIcons.database,
      ),
      SettingsSectionNavigationItem(
        value: XrayProfileUISection.fakeDns,
        title: localizations.fakeDnsPageTitle,
        description: localizations.xrayProfileUIPageFakeDnsDescription,
        group: localizations.xrayProfileUIPageGroupPolicy,
        icon: LucideIcons.globe2,
      ),
      SettingsSectionNavigationItem(
        value: XrayProfileUISection.log,
        title: localizations.logPageTitle,
        description: localizations.xrayProfileUIPageLogDescription,
        group: localizations.xrayProfileUIPageGroupDiagnostics,
        icon: LucideIcons.fileText,
      ),
    ];
  }

  Widget _sectionContent(
    BuildContext context,
    XrayProfileUIController controller,
    XrayProfileUIPageState state,
  ) {
    final profile = controller.profileState;
    return switch (state.section) {
      XrayProfileUISection.inbounds => InboundsView(
        onEditTun: () => controller.editTun(context),
        onEditSocks: () => controller.editSocks(context),
        onEditHttp: () => controller.editHttp(context),
        onEditPing: () => controller.editPing(context),
      ),
      XrayProfileUISection.outbounds => OutboundsView(
        state: profile.outbounds,
        onImportFinalOutbound: () => controller.importFinalOutbound(context),
        onDeleteFinalOutbound: controller.deleteFinalOutbound,
        onEditFreedom: () => controller.editFreedom(context),
        onEditFragment: () => controller.editFragment(context),
        onEditBlackHole: () => controller.editBlackHole(context),
        onEditDns: () => controller.editOutboundDns(context),
      ),
      XrayProfileUISection.routing => RoutingView(
        state: profile.routing,
        onUpdateDomainStrategy: controller.updateDomainStrategy,
        onShowSystemRule: (index) => controller.showSystemRule(context, index),
        onAppendCustomRule: controller.appendCustomRule,
        onSortCustomRule: controller.sortCustomRule,
        onEditCustomRule: (index) => controller.editCustomRule(context, index),
        onDeleteCustomRule: controller.deleteCustomRule,
      ),
      XrayProfileUISection.dns => DnsView(
        state: profile.dns,
        clientIpController: controller.dnsClientIpController,
        serveExpiredTTLController: controller.dnsServeExpiredTTLController,
        onEditHosts: () => controller.editHosts(context),
        onAppendServer: controller.appendDnsServer,
        onSortServer: controller.sortDnsServer,
        onEditServer: (index) => controller.editDnsServer(context, index),
        onDeleteServer: controller.deleteDnsServer,
        onUpdateDisableCache: controller.updateDisableCache,
        onUpdateServeStale: controller.updateServeStale,
        onUpdateDisableFallback: controller.updateDisableFallback,
        onUpdateDisableFallbackIfMatch: controller.updateDisableFallbackIfMatch,
        onUpdateEnableParallelQuery: controller.updateEnableParallelQuery,
        onUpdateUseSystemHosts: controller.updateUseSystemHosts,
      ),
      XrayProfileUISection.fakeDns => FakeDnsView(
        ipv4IpPoolController: controller.fakeDnsIpv4IpPoolController,
        ipv4PoolSizeController: controller.fakeDnsIpv4PoolSizeController,
        ipv6IpPoolController: controller.fakeDnsIpv6IpPoolController,
        ipv6PoolSizeController: controller.fakeDnsIpv6PoolSizeController,
      ),
      XrayProfileUISection.log => XrayLogView(
        state: profile.log,
        onUpdateLogLevel: controller.updateLogLevel,
        onUpdateDnsLog: controller.updateDnsLog,
        onUpdateMaskAddress: controller.updateMaskAddress,
      ),
    };
  }
}
