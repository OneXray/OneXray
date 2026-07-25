import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class XrayFullConfigOutboundsView extends StatelessWidget {
  final OutboundState? primaryProxy;
  final List<OutboundState> customOutbounds;
  final VoidCallback onEditPrimaryProxy;
  final VoidCallback onImportPrimaryProxy;
  final VoidCallback onAddCustomOutbound;
  final VoidCallback onImportCustomOutbound;
  final ValueChanged<OutboundState> onEditCustomOutbound;
  final ValueChanged<OutboundState> onDeleteCustomOutbound;
  final VoidCallback onEditFreedom;
  final VoidCallback onEditFragment;
  final VoidCallback onEditBlackHole;
  final VoidCallback onEditDns;

  const XrayFullConfigOutboundsView({
    super.key,
    required this.primaryProxy,
    required this.customOutbounds,
    required this.onEditPrimaryProxy,
    required this.onImportPrimaryProxy,
    required this.onAddCustomOutbound,
    required this.onImportCustomOutbound,
    required this.onEditCustomOutbound,
    required this.onDeleteCustomOutbound,
    required this.onEditFreedom,
    required this.onEditFragment,
    required this.onEditBlackHole,
    required this.onEditDns,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingSection(
            title: l10n.xrayFullConfigPrimaryProxy,
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
                  return NavigationSettingRow(
                    leading: const Icon(LucideIcons.server),
                    title:
                        primaryProxy?.name ?? l10n.xrayFullConfigProxyMissing,
                    value: compact ? null : "proxy",
                    subtitle: compact ? "proxy" : null,
                    onTap: onEditPrimaryProxy,
                  );
                },
              ),
            ],
          ),
          SettingSection(
            title: l10n.xrayFullConfigCustomOutbounds,
            description: l10n.xrayFullConfigCustomOutboundsDescription,
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
            title: l10n.outboundsPageSystem,
            children: [
              NavigationSettingRow(
                leading: const Icon(LucideIcons.cornerDownRight),
                title: l10n.outboundFreedomPageTitle,
                value: "direct",
                onTap: onEditFreedom,
              ),
              NavigationSettingRow(
                leading: const Icon(LucideIcons.scissors),
                title: l10n.outboundFragmentPageTitle,
                value: "fragment",
                onTap: onEditFragment,
              ),
              NavigationSettingRow(
                leading: const Icon(LucideIcons.ban),
                title: l10n.outboundBlackHolePageTitle,
                value: "block",
                onTap: onEditBlackHole,
              ),
              NavigationSettingRow(
                leading: const Icon(LucideIcons.database),
                title: l10n.outboundDnsPageTitle,
                value: "dnsOut",
                onTap: onEditDns,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _customOutboundRow(BuildContext context, OutboundState outbound) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final details = "${outbound.protocol.name} · ${outbound.network.name}";
        return SettingRow(
          leading: const Icon(LucideIcons.globe2),
          title: outbound.name,
          subtitle: compact ? "$details · ${outbound.tag}" : details,
          value: compact ? null : outbound.tag,
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
