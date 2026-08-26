import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/multi_node_outbound/controller.dart';
import 'package:onexray/pages/core/xray/multi_node_outbound/outbounds/view.dart';
import 'package:onexray/pages/core/xray/multi_node_outbound/params.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class XrayMultiNodeOutboundPage extends StatelessWidget {
  final XrayMultiNodeOutboundParams params;

  const XrayMultiNodeOutboundPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayMultiNodeOutboundController(params),
      child:
          BlocBuilder<
            XrayMultiNodeOutboundController,
            XrayMultiNodeOutboundPageState
          >(
            builder: (context, state) {
              final controller = context
                  .read<XrayMultiNodeOutboundController>();
              return SettingsPageScaffold(
                title: AppLocalizations.of(context)!.xrayMultiNodeOutboundTitle,
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
              l10n.xrayMultiNodeOutboundRawJsonHint,
              style: AppTypography.supporting.copyWith(
                color: ColorManager.secondaryText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameEditor(
    BuildContext context,
    XrayMultiNodeOutboundController controller,
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

  List<SettingsSectionNavigationItem<XrayMultiNodeOutboundSection>>
  _navigationItems(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return XrayMultiNodeOutboundSection.values
        .map((section) {
          return SettingsSectionNavigationItem(
            value: section,
            title: _sectionTitle(l10n, section),
            description: _commonSectionDescription(l10n, section),
            group: l10n.xrayMultiNodeOutboundGroupConfiguration,
            icon: _sectionIcon(section),
          );
        })
        .toList(growable: false);
  }

  Widget _sectionContent(
    BuildContext context,
    XrayMultiNodeOutboundController controller,
    XrayMultiNodeOutboundPageState state,
  ) {
    return switch (state.section) {
      XrayMultiNodeOutboundSection.outbounds =>
        XrayMultiNodeOutboundOutboundsView(
          primaryProxy: controller.primaryProxy,
          customOutbounds: controller.customOutbounds,
          onEditPrimaryProxy: () => controller.editPrimaryProxy(context),
          onImportPrimaryProxy: () => controller.importPrimaryProxy(context),
          onAddCustomOutbound: () => controller.addCustomOutbound(context),
          onImportCustomOutbound: () =>
              controller.importCustomOutbound(context),
          onEditCustomOutbound: (outbound) =>
              controller.editCustomOutbound(context, outbound),
          onDeleteCustomOutbound: (outbound) =>
              controller.deleteCustomOutbound(context, outbound),
          onEditRawJson: () => controller.editRoot(context, 'outbounds'),
        ),
      XrayMultiNodeOutboundSection.routing => _routingSection(
        context,
        controller,
      ),
      XrayMultiNodeOutboundSection.dns => _dnsSection(context, controller),
    };
  }

  Widget _dnsSection(
    BuildContext context,
    XrayMultiNodeOutboundController controller,
  ) {
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
                const DataListInlineEmptyRow(message: 'Raw JSON')
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
          _rawRootSetting(
            context,
            controller,
            XrayMultiNodeOutboundSection.dns,
          ),
        ],
      ),
    );
  }

  Widget _dnsServerRow(
    BuildContext context,
    XrayMultiNodeOutboundController controller,
    dynamic server,
    int index,
  ) {
    final editable = controller.isEditableDnsServer(server);
    final address = switch (server) {
      String value => value,
      Map value when value['address'] is String => value['address'] as String,
      _ => 'Raw JSON',
    };
    final port = server is Map && server['port'] is int
        ? '${server['port']}'
        : null;
    return ReorderableDelayedDragStartListener(
      key: ValueKey(index),
      index: index,
      child: DataListRow(
        title: address,
        subtitle: editable ? port : 'Raw JSON',
        onTap: editable
            ? () => _editDnsServer(context, controller, index, server)
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

  Future<void> _editDnsServer(
    BuildContext context,
    XrayMultiNodeOutboundController controller,
    int index,
    Map<dynamic, dynamic> server,
  ) async {
    var address = server['address'] as String? ?? '';
    var port = server['port']?.toString() ?? '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(l10n.dnsPageServers),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: address,
                onChanged: (value) => address = value,
                decoration: InputDecoration(
                  labelText: l10n.dnsServerPageAddress,
                  hintText: l10n.dnsServerPageAddressExample,
                ),
              ),
              TextFormField(
                initialValue: port,
                onChanged: (value) => port = value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.dnsServerPagePort,
                  hintText: l10n.dnsServerPagePortExample,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.buttonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.buttonSave),
            ),
          ],
        );
      },
    );
    if (accepted == true && context.mounted) {
      final updated = controller.updateDnsServer(index, address, port);
      if (!updated) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.validationPortInvalid,
        );
      }
    }
  }

  Widget _routingSection(
    BuildContext context,
    XrayMultiNodeOutboundController controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingSection(
            title: l10n.routingPageSectionStrategy,
            children: [
              if (controller.routingDomainStrategyRawOnly)
                const DataListInlineEmptyRow(message: 'Raw JSON')
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
          _rawRootSetting(
            context,
            controller,
            XrayMultiNodeOutboundSection.routing,
          ),
        ],
      ),
    );
  }

  Widget _rawRootSetting(
    BuildContext context,
    XrayMultiNodeOutboundController controller,
    XrayMultiNodeOutboundSection section,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final root = section.name;
    return SettingSection(
      title: l10n.xrayRawPageTitle,
      children: [
        NavigationSettingRow(
          leading: const Icon(LucideIcons.braces),
          title: '${l10n.menuEdit} $root JSON',
          value: controller.rootSummary(root),
          onTap: () => controller.editRoot(context, root),
        ),
      ],
    );
  }

  String _sectionTitle(
    AppLocalizations l10n,
    XrayMultiNodeOutboundSection section,
  ) {
    return switch (section) {
      XrayMultiNodeOutboundSection.outbounds => l10n.outboundsPageTitle,
      XrayMultiNodeOutboundSection.routing => l10n.routingPageTitle,
      XrayMultiNodeOutboundSection.dns => l10n.dnsPageTitle,
    };
  }

  String _commonSectionDescription(
    AppLocalizations l10n,
    XrayMultiNodeOutboundSection section,
  ) {
    return switch (section) {
      XrayMultiNodeOutboundSection.outbounds =>
        l10n.xrayProfileUIPageOutboundsDescription,
      XrayMultiNodeOutboundSection.routing =>
        l10n.xrayProfileUIPageRoutingDescription,
      XrayMultiNodeOutboundSection.dns => l10n.xrayProfileUIPageDnsDescription,
    };
  }

  IconData _sectionIcon(XrayMultiNodeOutboundSection section) {
    return switch (section) {
      XrayMultiNodeOutboundSection.outbounds => LucideIcons.waypoints,
      XrayMultiNodeOutboundSection.routing => LucideIcons.route,
      XrayMultiNodeOutboundSection.dns => LucideIcons.database,
    };
  }
}
