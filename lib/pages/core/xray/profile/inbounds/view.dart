import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/inbounds/view_data.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/additional_inbound_state.dart';

class InboundsView extends StatelessWidget {
  final InboundsViewData data;
  final VoidCallback onEditTun;
  final VoidCallback onEditPing;
  final ValueChanged<AdditionalInboundType> onAddAdditional;
  final ValueChanged<int> onEditAdditional;
  final ValueChanged<int> onDeleteAdditional;

  const InboundsView({
    super.key,
    required this.data,
    required this.onEditTun,
    required this.onEditPing,
    required this.onAddAdditional,
    required this.onEditAdditional,
    required this.onDeleteAdditional,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingsOverviewGrid(
            columns: 2,
            breakpoint: 900,
            children: [
              SettingSection(
                title: l10n.inboundsPageTunMode,
                children: [
                  NavigationSettingRow(
                    leading: const Icon(LucideIcons.radioTower),
                    title: l10n.inboundsPageTun,
                    onTap: onEditTun,
                  ),
                ],
              ),
              SettingSection(
                title: l10n.inboundsPageInternal,
                children: [
                  NavigationSettingRow(
                    leading: const Icon(LucideIcons.activity),
                    title: l10n.inboundsPagePing,
                    onTap: onEditPing,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _additionalSection(context),
        ],
      ),
    );
  }

  Widget _additionalSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.inboundsPageAdditional,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.serverCog),
          title: l10n.inboundsPageAdditional,
          subtitle: l10n.inboundsPageAdditionalDescription,
          trailing: AppMenuButton<AdditionalInboundType>(
            icon: LucideIcons.plus,
            entries: data.addItems
                .map(
                  (item) => AppMenuEntry<AdditionalInboundType>.item(
                    value: item.type,
                    title: item.title,
                  ),
                )
                .toList(),
            onSelected: onAddAdditional,
          ),
        ),
        ...data.additionalRows.map(_additionalRow),
      ],
    );
  }

  Widget _additionalRow(AdditionalInboundRowViewData row) {
    return SettingRow(
      leading: Icon(row.icon),
      title: row.title,
      subtitle: row.subtitle,
      onTap: () => onEditAdditional(row.index),
      trailing: AppMenuButton<IconMenuId>(
        icon: LucideIcons.ellipsis,
        entries: iconMenuEntries(<IconMenuId>[IconMenuId.delete]),
        onSelected: (_) => onDeleteAdditional(row.index),
      ),
    );
  }
}
