import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/log_state.dart';

class XrayLogView extends StatelessWidget {
  final LogState state;
  final ValueChanged<String> onUpdateLogLevel;
  final ValueChanged<bool> onUpdateDnsLog;
  final ValueChanged<String> onUpdateMaskAddress;

  const XrayLogView({
    super.key,
    required this.state,
    required this.onUpdateLogLevel,
    required this.onUpdateDnsLog,
    required this.onUpdateMaskAddress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      desktopMaxWidth: 760,
      child: Column(
        children: [
          SettingsPageIntro(title: l10n.xrayLogPageTitle),
          SettingSection(
            title: l10n.xrayLogPageTitle,
            children: [
              SelectSettingRow(
                leading: const Icon(LucideIcons.listFilter),
                title: l10n.xrayLogPageLogLevel,
                value: state.logLevel.name,
                selections: XrayLogLevel.names,
                onSelected: onUpdateLogLevel,
              ),
              SwitchSettingRow(
                leading: const Icon(LucideIcons.database),
                title: l10n.xrayLogPageDnsLog,
                value: state.dnsLog,
                onChanged: onUpdateDnsLog,
              ),
              SelectSettingRow(
                leading: const Icon(LucideIcons.shield),
                title: l10n.xrayLogPageMaskAddress,
                value: state.maskAddress.name,
                selections: XrayLogMaskAddress.names,
                onSelected: onUpdateMaskAddress,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
