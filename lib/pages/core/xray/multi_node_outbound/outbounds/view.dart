import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class XrayMultiNodeOutboundOutboundsView extends StatelessWidget {
  final Map<String, dynamic>? primaryProxy;
  final List<Map<String, dynamic>> customOutbounds;
  final VoidCallback onEditPrimaryProxy;
  final VoidCallback onImportPrimaryProxy;
  final VoidCallback onAddCustomOutbound;
  final VoidCallback onImportCustomOutbound;
  final ValueChanged<Map<String, dynamic>> onEditCustomOutbound;
  final ValueChanged<Map<String, dynamic>> onDeleteCustomOutbound;
  final VoidCallback onEditRawJson;

  const XrayMultiNodeOutboundOutboundsView({
    super.key,
    required this.primaryProxy,
    required this.customOutbounds,
    required this.onEditPrimaryProxy,
    required this.onImportPrimaryProxy,
    required this.onAddCustomOutbound,
    required this.onImportCustomOutbound,
    required this.onEditCustomOutbound,
    required this.onDeleteCustomOutbound,
    required this.onEditRawJson,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryProxy = this.primaryProxy;
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingSection(
            title: l10n.xrayMultiNodeOutboundPrimaryProxy,
            action: ShadButton.outline(
              size: ShadButtonSize.sm,
              leading: const Icon(LucideIcons.waypoints, size: 15),
              onPressed: onImportPrimaryProxy,
              child: Text(l10n.buttonImport),
            ),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final details = primaryProxy == null
                      ? null
                      : [
                              outboundString(primaryProxy, 'protocol'),
                              outboundNetwork(primaryProxy),
                            ]
                            .whereType<String>()
                            .where((value) => value.isNotEmpty)
                            .join(' · ');
                  return NavigationSettingRow(
                    leading: const Icon(LucideIcons.server),
                    title: primaryProxy == null
                        ? l10n.xrayMultiNodeOutboundProxyMissing
                        : outboundDisplayName(primaryProxy),
                    value: compact ? null : details,
                    subtitle: compact ? details : null,
                    onTap: onEditPrimaryProxy,
                  );
                },
              ),
            ],
          ),
          SettingSection(
            title: l10n.xrayMultiNodeOutboundCustomOutbounds,
            description: l10n.xrayMultiNodeOutboundCustomOutboundsDescription,
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  leading: const Icon(LucideIcons.waypoints, size: 15),
                  onPressed: onImportCustomOutbound,
                  child: Text(l10n.buttonImport),
                ),
                const SizedBox(width: 6),
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  leading: const Icon(LucideIcons.plus, size: 15),
                  onPressed: onAddCustomOutbound,
                  child: Text(l10n.buttonAdd),
                ),
              ],
            ),
            children: customOutbounds
                .map((outbound) => _customOutboundRow(context, outbound))
                .toList(),
          ),
          SettingSection(
            title: l10n.xrayRawPageTitle,
            description: l10n.outboundUIPageRawJsonHint,
            children: [
              NavigationSettingRow(
                leading: const Icon(LucideIcons.braces),
                title: '${l10n.menuEdit} outbounds JSON',
                value: 'outbounds',
                onTap: onEditRawJson,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _customOutboundRow(
    BuildContext context,
    Map<String, dynamic> outbound,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final details = [
          outboundString(outbound, 'protocol'),
          outboundNetwork(outbound),
        ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
        return SettingRow(
          leading: const Icon(LucideIcons.globe2),
          title: outboundDisplayName(outbound),
          subtitle: compact ? details : null,
          value: compact ? null : details,
          onTap: () => onEditCustomOutbound(outbound),
          trailing: ActionCluster(
            children: [
              if (!compact)
                IconButton(
                  tooltip: AppLocalizations.of(context)!.menuEdit,
                  onPressed: () => onEditCustomOutbound(outbound),
                  icon: const Icon(LucideIcons.pencil, size: 17),
                ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.menuDelete,
                onPressed: () => onDeleteCustomOutbound(outbound),
                icon: const Icon(LucideIcons.trash2, size: 17),
              ),
            ],
          ),
        );
      },
    );
  }
}
