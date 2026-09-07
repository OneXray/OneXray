import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/shared/widgets/setting_row.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:onexray/pages/shared/widgets/settings_page.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/event_bus/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:onexray/pages/settings/widgets.dart';

class AboutOneXrayPage extends StatelessWidget {
  const AboutOneXrayPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SettingsController(),
    child: BlocBuilder<SettingsController, SettingsPageState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final controller = context.read<SettingsController>();
        final mobile =
            MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.prototypeAboutOneXray)),
          body: SafeArea(
            child: SettingsPageScroll(
              desktopMaxWidth: AppLayout.routingMaxWidth,
              alignment: AlignmentDirectional.topStart,
              padding: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  mobile ? 14 : AppSpacing.page,
                  mobile ? 17 : AppSpacing.desktopPageTop,
                  mobile ? 14 : AppSpacing.page,
                  mobile ? 26 : AppSpacing.desktopPageBottom + 26,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (mobile) ...[
                      Text(
                        l10n.prototypeAppInformation,
                        style: AppTypography.settingsDetailNote.copyWith(
                          color: ColorManager.secondaryText(context),
                        ),
                      ),
                      const SizedBox(height: 23),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: state.appIcon.assetImage.image(
                              width: 74,
                              height: 74,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text('OneXray', style: AppTypography.aboutBrandTitle),
                          const SizedBox(height: 9),
                          Text(
                            l10n.prototypeCrossPlatformXrayClient,
                            style: AppTypography.aboutBrandDescription.copyWith(
                              color: ColorManager.secondaryText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: mobile ? 23 : 24),
                    SettingSection(
                      title: '',
                      padding: EdgeInsets.zero,
                      dividerIndent: 0,
                      children: [
                        SettingsVersionRow(
                          label: l10n.prototypeAppVersion,
                          value: state.appVersion,
                          compact: true,
                          style: mobile
                              ? AppTypography.settingsVersion
                              : AppTypography.desktopSettingsVersion,
                        ),
                        SettingsVersionRow(
                          label: 'Xray-core',
                          value: state.xrayVersion,
                          compact: true,
                          style: mobile
                              ? AppTypography.settingsVersion
                              : AppTypography.desktopSettingsVersion,
                        ),
                        BlocBuilder<AppEventBus, AppEventBusState>(
                          builder: (context, preferences) => SettingRow(
                            title: l10n.prototypeCheckAppUpdates,
                            minHeight: 64,
                            titleStyle: AppTypography.settingsRow,
                            subtitleStyle: mobile
                                ? AppTypography.settingsChoiceDetail
                                : AppTypography.desktopSettingsHint,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: mobile ? 13 : 14,
                              vertical: 12,
                            ),
                            subtitle: preferences.appUpdateInfo == null
                                ? l10n.prototypeCheckNewVersions
                                : l10n.prototypeVersionAvailable(
                                    preferences.appUpdateInfo!.latestVersion,
                                  ),
                            trailing:
                                preferences.downloading || state.checkingUpdate
                                ? const ButtonProgressIndicator(size: 20)
                                : Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Icon(
                                        LucideIcons.download,
                                        size: 18,
                                      ),
                                      if (preferences.appUpdateInfo != null)
                                        const PositionedDirectional(
                                          end: -4,
                                          top: -4,
                                          child: SettingsUpdateDot(),
                                        ),
                                    ],
                                  ),
                            onTap: state.checkingUpdate
                                ? null
                                : () => controller.checkUpdate(context),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: mobile ? 23 : 24),
                    SettingSection(
                      title: l10n.prototypeHelpCommunity,
                      headerInset: 0,
                      icon: LucideIcons.circleHelp,
                      padding: EdgeInsets.zero,
                      dividerIndent: 0,
                      children: [
                        _LinkRow(
                          label: l10n.prototypeDocumentation,
                          icon: LucideIcons.bookOpen,
                          link: SettingsLink.documentation,
                        ),
                        if (AppPlatform.isMobile || AppPlatform.isMacOS)
                          _LinkRow(
                            label: l10n.prototypeRateOneXray,
                            icon: LucideIcons.star,
                            link: SettingsLink.review,
                          ),
                        _LinkRow(
                          label: l10n.prototypeCommunity,
                          icon: LucideIcons.send,
                          link: SettingsLink.community,
                        ),
                        _LinkRow(
                          label: l10n.prototypeSendFeedback,
                          icon: LucideIcons.bug,
                          link: SettingsLink.feedback,
                        ),
                        _LinkRow(
                          label: l10n.prototypeSourceCode,
                          icon: LucideIcons.code2,
                          link: SettingsLink.source,
                        ),
                        _LinkRow(
                          label: l10n.prototypeAcknowledgements,
                          icon: LucideIcons.circleHelp,
                          link: SettingsLink.credits,
                        ),
                        _LinkRow(
                          label: l10n.prototypePrivacyPolicy,
                          icon: LucideIcons.shieldCheck,
                          link: SettingsLink.privacy,
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: mobile ? 13 : 14),
                      child: Text(
                        l10n.prototypeAboutPrivacyNotice,
                        style: AppTypography.settingsDetailNote.copyWith(
                          color: ColorManager.secondaryText(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _LinkRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final SettingsLink link;
  const _LinkRow({required this.label, required this.icon, required this.link});
  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return SettingRow(
      title: label,
      minHeight: mobile ? 43 : 56,
      titleStyle: AppTypography.settingsRow,
      contentPadding: EdgeInsets.symmetric(
        horizontal: mobile ? 13 : 14,
        vertical: 10,
      ),
      trailing: const Icon(LucideIcons.chevronRightDir, size: 17),
      onTap: () => context.read<SettingsController>().openLink(context, link),
    );
  }
}
