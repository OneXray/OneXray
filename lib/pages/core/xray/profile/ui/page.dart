import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/ui/controller.dart';
import 'package:onexray/pages/core/xray/profile/ui/params.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/enum.dart';
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
            onSave: state.loaded && !state.saving
                ? () => controller.save(context)
                : null,
            saveLoading: state.saving,
            actions: [
              IconButton(
                tooltip: AppLocalizations.of(context)!.xrayRawPageTitle,
                onPressed: state.loaded && !state.saving
                    ? () => controller.gotoRawEdit(context)
                    : null,
                icon: const Icon(LucideIcons.braces),
              ),
            ],
            body: IgnorePointer(
              ignoring: !state.loaded || state.saving,
              child: Column(
                children: [
                  _rawJsonHint(context),
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
                              child: _sectionContent(
                                context,
                                controller,
                                state,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _rawJsonHint(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 10),
      color: ColorManager.tagBackground(context),
      child: Row(
        children: [
          Icon(
            LucideIcons.info,
            size: 17,
            color: ColorManager.secondaryText(context),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              l10n.xrayProfileUIRawJsonHint,
              style: AppTypography.supporting.copyWith(
                color: ColorManager.secondaryText(context),
              ),
            ),
          ),
        ],
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
    final l10n = AppLocalizations.of(context)!;
    return XrayProfileUISection.values
        .map(
          (section) => SettingsSectionNavigationItem(
            value: section,
            title: _sectionTitle(l10n, section),
            description: _sectionDescription(l10n, section),
            group: _sectionGroup(l10n, section),
            icon: _sectionIcon(section),
          ),
        )
        .toList(growable: false);
  }

  Widget _sectionContent(
    BuildContext context,
    XrayProfileUIController controller,
    XrayProfileUIPageState state,
  ) {
    return switch (state.section) {
      XrayProfileUISection.inbounds => _rawOnlySection(
        context,
        controller,
        'inbounds',
      ),
      XrayProfileUISection.outbounds => _rawOnlySection(
        context,
        controller,
        'outbounds',
      ),
      XrayProfileUISection.routing => _routingSection(context, controller),
      XrayProfileUISection.dns => _dnsSection(context, controller),
      XrayProfileUISection.fakeDns => _fakeDnsSection(context, controller),
      XrayProfileUISection.log => _logSection(context, controller),
      XrayProfileUISection.advanced => _advancedSection(context, controller),
    };
  }

  Widget _rawOnlySection(
    BuildContext context,
    XrayProfileUIController controller,
    String root,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      child: SettingSection(
        title: l10n.xrayRawPageTitle,
        description: l10n.xrayProfileUIRawOnly,
        children: [_rawRootRow(context, controller, root)],
      ),
    );
  }

  Widget _routingSection(
    BuildContext context,
    XrayProfileUIController controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingSection(
            title: l10n.routingPageSectionStrategy,
            children: [
              if (controller.routingRawOnly)
                DataListInlineEmptyRow(message: l10n.xrayProfileUIRawOnly)
              else
                SelectSettingRow<String>(
                  leading: const Icon(LucideIcons.route),
                  title: l10n.routingPageDomainStrategy,
                  value: controller.routingDomainStrategy,
                  selections: RoutingDomainStrategy.names,
                  onSelected: controller.updateDomainStrategy,
                ),
            ],
          ),
          _rawRootSetting(context, controller, 'routing'),
        ],
      ),
    );
  }

  Widget _dnsSection(BuildContext context, XrayProfileUIController controller) {
    final l10n = AppLocalizations.of(context)!;
    final servers = controller.dnsServers;
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingSection(
            title: l10n.dnsPageSectionServers,
            action: controller.dnsServersRawOnly
                ? null
                : ShadButton.outline(
                    size: ShadButtonSize.sm,
                    leading: const Icon(LucideIcons.plus, size: 15),
                    onPressed: controller.addDnsServer,
                    child: Text(l10n.buttonAdd),
                  ),
            children: [
              if (controller.dnsServersRawOnly)
                DataListInlineEmptyRow(message: l10n.xrayProfileUIRawOnly)
              else if (servers.isEmpty)
                DataListInlineEmptyRow(message: l10n.dnsPageServers)
              else
                ReorderableListView(
                  buildDefaultDragHandles: false,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorderItem: controller.reorderDnsServer,
                  children: [
                    for (var index = 0; index < servers.length; index++)
                      _dnsServerRow(context, controller, servers[index], index),
                  ],
                ),
            ],
          ),
          _rawRootSetting(context, controller, 'dns'),
        ],
      ),
    );
  }

  Widget _dnsServerRow(
    BuildContext context,
    XrayProfileUIController controller,
    dynamic server,
    int index,
  ) {
    final editable = controller.isEditableDnsServer(server);
    final address = switch (server) {
      Map value when value['address'] is String => value['address'] as String,
      _ => 'Raw JSON',
    };
    final port = server is Map && server['port'] is int
        ? '${server['port']}'
        : editable
        ? null
        : 'Raw JSON';
    return ReorderableDelayedDragStartListener(
      key: ValueKey(index),
      index: index,
      child: DataListRow(
        title: address,
        subtitle: port,
        onTap: editable
            ? () => controller.editDnsServer(context, index)
            : () => controller.editRoot(context, 'dns'),
        trailing: ActionCluster(
          children: [
            IconButton(
              tooltip: AppLocalizations.of(context)!.menuDelete,
              onPressed: () => controller.deleteDnsServer(index),
              icon: const Icon(LucideIcons.trash2, size: 17),
            ),
            ReorderDragHandle(
              index: index,
              tooltip: AppLocalizations.of(context)!.helpOrder,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fakeDnsSection(
    BuildContext context,
    XrayProfileUIController controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingSection(
            title: l10n.fakeDnsPageTitle,
            children: controller.fakeDnsRawOnly
                ? [DataListInlineEmptyRow(message: l10n.xrayProfileUIRawOnly)]
                : [
                    _fakeDnsPoolRow(context, controller, ipv6: false),
                    _fakeDnsPoolRow(context, controller, ipv6: true),
                  ],
          ),
          _rawRootSetting(context, controller, 'fakeDns'),
        ],
      ),
    );
  }

  Widget _fakeDnsPoolRow(
    BuildContext context,
    XrayProfileUIController controller, {
    required bool ipv6,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final pool = controller.fakeDnsPool(ipv6);
    final ipPool = pool?['ipPool'] as String? ?? '-';
    final poolSize = pool?['poolSize'];
    return NavigationSettingRow(
      leading: Icon(ipv6 ? LucideIcons.network : LucideIcons.globe2),
      title: ipv6 ? l10n.fakeDnsPageIPv6 : l10n.fakeDnsPageIPv4,
      value: poolSize == null ? ipPool : '$ipPool / $poolSize',
      onTap: () => controller.editFakeDnsPool(context, ipv6: ipv6),
    );
  }

  Widget _logSection(BuildContext context, XrayProfileUIController controller) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingSection(
            title: l10n.xrayLogPageTitle,
            children: controller.logRawOnly
                ? [DataListInlineEmptyRow(message: l10n.xrayProfileUIRawOnly)]
                : [
                    SelectSettingRow<String>(
                      leading: const Icon(LucideIcons.listFilter),
                      title: l10n.xrayLogPageLogLevel,
                      value: controller.logLevel,
                      selections: XrayLogLevel.names,
                      onSelected: controller.updateLogLevel,
                    ),
                    SwitchSettingRow(
                      leading: const Icon(LucideIcons.database),
                      title: l10n.xrayLogPageDnsLog,
                      value: controller.dnsLog,
                      onChanged: controller.updateDnsLog,
                    ),
                    SelectSettingRow<String>(
                      leading: const Icon(LucideIcons.shield),
                      title: l10n.xrayLogPageMaskAddress,
                      value: controller.maskAddress,
                      selections: XrayLogMaskAddress.names,
                      onSelected: controller.updateMaskAddress,
                    ),
                  ],
          ),
          _rawRootSetting(context, controller, 'log'),
        ],
      ),
    );
  }

  Widget _advancedSection(
    BuildContext context,
    XrayProfileUIController controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      child: SettingSection(
        title: l10n.xrayProfileUIAdvancedTitle,
        description: l10n.xrayProfileUIRawOnly,
        children: [
          for (final root in xrayProfileAdvancedRoots)
            if (xrayProfileReadOnlyRoots.contains(root))
              SettingRow(
                leading: const Icon(LucideIcons.braces),
                title: root,
                value: controller.rootJson(root),
                valueMaxLines: 4,
              )
            else
              _rawRootRow(context, controller, root),
        ],
      ),
    );
  }

  Widget _rawRootSetting(
    BuildContext context,
    XrayProfileUIController controller,
    String root,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.xrayRawPageTitle,
      children: [_rawRootRow(context, controller, root)],
    );
  }

  Widget _rawRootRow(
    BuildContext context,
    XrayProfileUIController controller,
    String root,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return NavigationSettingRow(
      leading: const Icon(LucideIcons.braces),
      title: '${l10n.menuEdit} $root JSON',
      value: controller.rootSummary(root),
      onTap: () => controller.editRoot(context, root),
    );
  }

  String _sectionTitle(AppLocalizations l10n, XrayProfileUISection section) {
    return switch (section) {
      XrayProfileUISection.inbounds => l10n.inboundsPageTitle,
      XrayProfileUISection.outbounds => l10n.outboundsPageTitle,
      XrayProfileUISection.routing => l10n.routingPageTitle,
      XrayProfileUISection.dns => l10n.dnsPageTitle,
      XrayProfileUISection.fakeDns => l10n.fakeDnsPageTitle,
      XrayProfileUISection.log => l10n.logPageTitle,
      XrayProfileUISection.advanced => l10n.xrayProfileUIAdvancedTitle,
    };
  }

  String _sectionDescription(
    AppLocalizations l10n,
    XrayProfileUISection section,
  ) {
    return switch (section) {
      XrayProfileUISection.inbounds =>
        l10n.xrayProfileUIPageInboundsDescription,
      XrayProfileUISection.outbounds =>
        l10n.xrayProfileUIPageOutboundsDescription,
      XrayProfileUISection.routing => l10n.xrayProfileUIPageRoutingDescription,
      XrayProfileUISection.dns => l10n.xrayProfileUIPageDnsDescription,
      XrayProfileUISection.fakeDns => l10n.xrayProfileUIPageFakeDnsDescription,
      XrayProfileUISection.log => l10n.xrayProfileUIPageLogDescription,
      XrayProfileUISection.advanced => l10n.xrayProfileUIAdvancedDescription,
    };
  }

  String _sectionGroup(AppLocalizations l10n, XrayProfileUISection section) {
    return switch (section) {
      XrayProfileUISection.inbounds ||
      XrayProfileUISection.outbounds => l10n.xrayProfileUIPageGroupRuntime,
      XrayProfileUISection.routing ||
      XrayProfileUISection.dns ||
      XrayProfileUISection.fakeDns => l10n.xrayProfileUIPageGroupPolicy,
      XrayProfileUISection.log ||
      XrayProfileUISection.advanced => l10n.xrayProfileUIPageGroupDiagnostics,
    };
  }

  IconData _sectionIcon(XrayProfileUISection section) {
    return switch (section) {
      XrayProfileUISection.inbounds => LucideIcons.radioTower,
      XrayProfileUISection.outbounds => LucideIcons.waypoints,
      XrayProfileUISection.routing => LucideIcons.route,
      XrayProfileUISection.dns => LucideIcons.database,
      XrayProfileUISection.fakeDns => LucideIcons.globe2,
      XrayProfileUISection.log => LucideIcons.fileText,
      XrayProfileUISection.advanced => LucideIcons.settings2,
    };
  }
}
