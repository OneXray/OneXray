import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class FinalOutboundSection extends StatelessWidget {
  const FinalOutboundSection({
    super.key,
    required this.name,
    required this.onSelect,
    this.onDelete,
  });

  final String? name;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final outboundName = name;
    final delete = onDelete;
    return SettingSection(
      title: l10n.finalOutboundPageTitle,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.waypoints),
          title: outboundName == null || outboundName.isEmpty
              ? l10n.finalOutboundPageDisabled
              : outboundName,
          onTap: onSelect,
          showChevron: delete == null,
          trailing: delete == null
              ? null
              : IconButton(
                  tooltip: l10n.finalOutboundPageDelete,
                  onPressed: delete,
                  icon: const Icon(LucideIcons.trash2, size: 17),
                ),
        ),
      ],
    );
  }
}
