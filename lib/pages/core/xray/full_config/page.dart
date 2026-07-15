import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/full_config/controller.dart';
import 'package:onexray/pages/core/xray/full_config/outbounds/view.dart';
import 'package:onexray/pages/core/xray/full_config/params.dart';
import 'package:onexray/pages/core/xray/profile/dns/view.dart';
import 'package:onexray/pages/core/xray/profile/routing/view.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class XrayFullConfigPage extends StatelessWidget {
  final XrayFullConfigParams params;

  const XrayFullConfigPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayFullConfigController(params),
      child: BlocBuilder<XrayFullConfigController, XrayFullConfigPageState>(
        builder: (context, state) {
          final controller = context.read<XrayFullConfigController>();
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.xrayFullConfigTitle,
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

  Widget _nameEditor(
    BuildContext context,
    XrayFullConfigController controller,
  ) {
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

  List<SettingsSectionNavigationItem<XrayFullConfigSection>> _navigationItems(
    BuildContext context,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return [
      SettingsSectionNavigationItem(
        value: XrayFullConfigSection.outbounds,
        title: l10n.outboundsPageTitle,
        description: l10n.xrayProfileUIPageOutboundsDescription,
        group: l10n.xrayFullConfigGroupConfiguration,
        icon: LucideIcons.waypoints,
      ),
      SettingsSectionNavigationItem(
        value: XrayFullConfigSection.routing,
        title: l10n.routingPageTitle,
        description: l10n.xrayProfileUIPageRoutingDescription,
        group: l10n.xrayFullConfigGroupConfiguration,
        icon: LucideIcons.route,
      ),
      SettingsSectionNavigationItem(
        value: XrayFullConfigSection.dns,
        title: l10n.dnsPageTitle,
        description: l10n.xrayProfileUIPageDnsDescription,
        group: l10n.xrayFullConfigGroupConfiguration,
        icon: LucideIcons.database,
      ),
    ];
  }

  Widget _sectionContent(
    BuildContext context,
    XrayFullConfigController controller,
    XrayFullConfigPageState state,
  ) {
    final fullConfig = controller.fullConfigState;
    return switch (state.section) {
      XrayFullConfigSection.outbounds => XrayFullConfigOutboundsView(
        primaryProxy: controller.primaryProxy,
        customOutbounds: controller.customOutbounds,
        onEditPrimaryProxy: () => controller.editPrimaryProxy(context),
        onImportPrimaryProxy: () => controller.importPrimaryProxy(context),
        onAddCustomOutbound: () => controller.addCustomOutbound(context),
        onImportCustomOutbound: () => controller.importCustomOutbound(context),
        onEditCustomOutbound: (outbound) =>
            controller.editCustomOutbound(context, outbound),
        onDeleteCustomOutbound: controller.deleteCustomOutbound,
        onEditFreedom: () => controller.editFreedom(context),
        onEditFragment: () => controller.editFragment(context),
        onEditBlackHole: () => controller.editBlackHole(context),
        onEditDns: () => controller.editOutboundDns(context),
      ),
      XrayFullConfigSection.routing => RoutingView(
        state: fullConfig.routing,
        onUpdateDomainStrategy: controller.updateDomainStrategy,
        onShowSystemRule: (index) => controller.showSystemRule(context, index),
        onAppendCustomRule: controller.appendCustomRule,
        onSortCustomRule: controller.sortCustomRule,
        onEditCustomRule: (index) => controller.editCustomRule(context, index),
        onDeleteCustomRule: controller.deleteCustomRule,
      ),
      XrayFullConfigSection.dns => DnsView(
        state: fullConfig.dns,
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
    };
  }
}
