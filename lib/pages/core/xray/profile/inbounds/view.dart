import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/additional_inbound_state.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';

class InboundsView extends StatelessWidget {
  final InboundsState state;
  final VoidCallback onEditTun;
  final VoidCallback onEditPing;
  final ValueChanged<AdditionalInboundType> onAddAdditional;
  final ValueChanged<int> onEditAdditional;
  final ValueChanged<int> onDeleteAdditional;

  const InboundsView({
    super.key,
    required this.state,
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
            entries: AdditionalInboundType.values
                .map(
                  (type) => AppMenuEntry<AdditionalInboundType>.item(
                    value: type,
                    title: _typeTitle(context, type),
                  ),
                )
                .toList(),
            onSelected: onAddAdditional,
          ),
        ),
        ...state.additional.asMap().entries.map(
          (entry) => _additionalRow(context, entry.key, entry.value),
        ),
      ],
    );
  }

  Widget _additionalRow(
    BuildContext context,
    int index,
    AdditionalInboundState inbound,
  ) {
    return SettingRow(
      leading: Icon(_typeIcon(inbound.type)),
      title: inbound.tag,
      subtitle: _inboundDescription(context, inbound),
      onTap: () => onEditAdditional(index),
      trailing: AppMenuButton<IconMenuId>(
        icon: LucideIcons.ellipsis,
        entries: iconMenuEntries(<IconMenuId>[IconMenuId.delete]),
        onSelected: (_) => onDeleteAdditional(index),
      ),
    );
  }

  String _inboundDescription(
    BuildContext context,
    AdditionalInboundState inbound,
  ) {
    final listen = inbound.listen.isEmpty
        ? AppLocalizations.of(context)!.inboundAdditionalPageAllInterfaces
        : inbound.listen;
    final listener = '$listen:${inbound.port}';
    if (inbound is InboundDokodemoDoorState) {
      return '$listener → ${inbound.targetAddress}:${inbound.targetPort}';
    }
    return '${_typeTitle(context, inbound.type)} · $listener';
  }

  String _typeTitle(BuildContext context, AdditionalInboundType type) {
    final l10n = AppLocalizations.of(context)!;
    return switch (type) {
      AdditionalInboundType.socks => l10n.inboundsPageAddSocks,
      AdditionalInboundType.http => l10n.inboundsPageAddHttp,
      AdditionalInboundType.dokodemoDoor => l10n.inboundsPageAddDokodemoDoor,
    };
  }

  IconData _typeIcon(AdditionalInboundType type) {
    return switch (type) {
      AdditionalInboundType.socks => LucideIcons.network,
      AdditionalInboundType.http => LucideIcons.globe2,
      AdditionalInboundType.dokodemoDoor => LucideIcons.arrowRightLeft,
    };
  }
}
