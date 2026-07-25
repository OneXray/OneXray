import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/outbounds/final_outbound_section.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/outbounds_state.dart';

class OutboundsView extends StatelessWidget {
  final OutboundsState state;
  final VoidCallback onImportFinalOutbound;
  final VoidCallback onDeleteFinalOutbound;
  final VoidCallback onEditFreedom;
  final VoidCallback onEditFragment;
  final VoidCallback onEditBlackHole;
  final VoidCallback onEditDns;

  const OutboundsView({
    super.key,
    required this.state,
    required this.onImportFinalOutbound,
    required this.onDeleteFinalOutbound,
    required this.onEditFreedom,
    required this.onEditFragment,
    required this.onEditBlackHole,
    required this.onEditDns,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingsOverviewGrid(
            breakpoint: 860,
            children: [
              FinalOutboundSection(
                name: state.finalOutbound?.name,
                onSelect: onImportFinalOutbound,
                onDelete: state.finalOutbound == null
                    ? null
                    : onDeleteFinalOutbound,
              ),
              _systemSection(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _systemSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.outboundsPageSystem,
      children: [
        NavigationSettingRow(
          leading: const Icon(LucideIcons.cornerDownRight),
          title: l10n.outboundFreedomPageTitle,
          onTap: onEditFreedom,
        ),
        NavigationSettingRow(
          leading: const Icon(LucideIcons.scissors),
          title: l10n.outboundFragmentPageTitle,
          onTap: onEditFragment,
        ),
        NavigationSettingRow(
          leading: const Icon(LucideIcons.ban),
          title: l10n.outboundBlackHolePageTitle,
          onTap: onEditBlackHole,
        ),
        NavigationSettingRow(
          leading: const Icon(LucideIcons.database),
          title: l10n.outboundDnsPageTitle,
          onTap: onEditDns,
        ),
      ],
    );
  }
}
