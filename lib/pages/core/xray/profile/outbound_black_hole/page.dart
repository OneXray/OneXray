import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/outbound_black_hole/controller.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class OutboundBlackHolePage extends StatelessWidget {
  const OutboundBlackHolePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = OutboundBlackHoleController();
    final localizations = AppLocalizations.of(context)!;
    return SettingsPageScaffold(
      title: localizations.outboundBlackHolePageTitle,
      body: SettingsPageScroll(
        desktopMaxWidth: 760,
        child: SettingSection(
          title: localizations.outboundBlackHolePageTitle,
          children: [
            SettingRow(
              leading: const Icon(LucideIcons.waypoints),
              title: localizations.outboundBlackHolePageProtocol,
              value: controller.blackHoleState.protocol.name,
            ),
            SettingRow(
              leading: const Icon(LucideIcons.tag),
              title: localizations.outboundBlackHolePageTag,
              value: controller.blackHoleState.tag.name,
            ),
          ],
        ),
      ),
    );
  }
}
