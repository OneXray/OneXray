import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';

class InboundsView extends StatelessWidget {
  final VoidCallback onEditTun;
  final VoidCallback onEditPing;

  const InboundsView({
    super.key,
    required this.onEditTun,
    required this.onEditPing,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingsPageIntro(title: l10n.inboundsPageTitle),
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
        ],
      ),
    );
  }
}
