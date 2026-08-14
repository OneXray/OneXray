import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/general/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class GeneralSettingsPage extends StatelessWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GeneralSettingsController(),
      child: BlocBuilder<GeneralSettingsController, GeneralSettingsPageState>(
        builder: (context, state) {
          final controller = context.read<GeneralSettingsController>();
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.settingsPageGeneral,
            body: GeneralSettingsView(
              state: state,
              onConnectOnAppLaunchChanged: controller.updateConnectOnAppLaunch,
              onUserAgentModeChanged: controller.updateUserAgentMode,
            ),
          );
        },
      ),
    );
  }
}

class GeneralSettingsView extends StatelessWidget {
  final GeneralSettingsPageState state;
  final ValueChanged<bool> onConnectOnAppLaunchChanged;
  final ValueChanged<DownloadUserAgentMode> onUserAgentModeChanged;

  const GeneralSettingsView({
    super.key,
    required this.state,
    required this.onConnectOnAppLaunchChanged,
    required this.onUserAgentModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userAgentEnabled = !state.loading && !state.updatingUserAgentMode;
    return SettingsPageScroll(
      desktopMaxWidth: 720,
      child: Column(
        children: [
          SettingSection(
            title: l10n.generalSettingsPageSectionStartup,
            children: [
              SwitchSettingRow(
                title: l10n.settingsPageConnectOnLaunch,
                subtitle: l10n.settingsPageConnectOnLaunchDescription,
                leading: const Icon(LucideIcons.power),
                value: state.connectOnAppLaunch,
                onChanged: state.loading ? null : onConnectOnAppLaunchChanged,
              ),
            ],
          ),
          SettingSection(
            title: l10n.generalSettingsPageUserAgent,
            children: [
              SettingsChoiceRow(
                title: l10n.generalSettingsPageSystemUserAgent,
                description: l10n.generalSettingsPageSystemUserAgentDescription,
                leading: const Icon(LucideIcons.globe2),
                selected: state.userAgentMode == DownloadUserAgentMode.system,
                onTap: !userAgentEnabled
                    ? null
                    : () =>
                          onUserAgentModeChanged(DownloadUserAgentMode.system),
              ),
              SettingsChoiceRow(
                title: l10n.generalSettingsPageOneXrayUserAgent,
                description:
                    l10n.generalSettingsPageOneXrayUserAgentDescription,
                leading: const Icon(LucideIcons.appWindow),
                selected: state.userAgentMode == DownloadUserAgentMode.oneXray,
                onTap: !userAgentEnabled
                    ? null
                    : () =>
                          onUserAgentModeChanged(DownloadUserAgentMode.oneXray),
              ),
              if (state.userAgent.isNotEmpty)
                _UserAgentPreview(userAgent: state.userAgent),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserAgentPreview extends StatelessWidget {
  final String userAgent;

  const _UserAgentPreview({required this.userAgent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: ColorManager.tagBackground(context).withValues(alpha: 0.45),
      padding: const EdgeInsetsDirectional.fromSTEB(13, 11, 13, 12),
      child: SelectableText(
        userAgent,
        textDirection: TextDirection.ltr,
        style: AppTypography.code.copyWith(
          color: ColorManager.secondaryText(context),
        ),
      ),
    );
  }
}
