import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/auto_update/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/auto_update/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AutoUpdatePage extends StatelessWidget {
  const AutoUpdatePage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AutoUpdateController(),
    child: BlocBuilder<AutoUpdateController, AutoUpdatePageState>(
      builder: (context, state) {
        final controller = context.read<AutoUpdateController>();
        final l = AppLocalizations.of(context)!;
        final value = state.autoUpdateState;
        final mobile =
            MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
        return Scaffold(
          appBar: AppBar(title: Text(l.prototypeDataUpdates)),
          bottomNavigationBar: PageActionBar(
            children: [
              OutlinedButton(
                onPressed: state.saving
                    ? null
                    : () => controller.cancel(context),
                child: Text(l.prototypeCancel),
              ),
              FilledButton(
                onPressed: !state.loaded || state.saving
                    ? null
                    : () => controller.save(context),
                child: Text(l.prototypeSave),
              ),
            ],
          ),
          body: SafeArea(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : !state.loaded
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.prototypeTemporarilyUnavailable),
                        TextButton(
                          onPressed: controller.load,
                          child: Text(l.prototypeRetry),
                        ),
                      ],
                    ),
                  )
                : SettingsPageScroll(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      14,
                      12,
                      14,
                      26,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 25,
                      children: [
                        if (!mobile)
                          Text(
                            l.prototypeDataUpdateIntervalsHint,
                            style: AppTypography.settingsDetailNote.copyWith(
                              color: ColorManager.secondaryText(context),
                            ),
                          ),
                        SettingSection(
                          title: l.prototypeSubscriptions,
                          icon: LucideIcons.refreshCw,
                          padding: EdgeInsets.zero,
                          dividerIndent: 0,
                          description: l.prototypeSubscriptionUpdateGuard,
                          descriptionBelow: true,
                          children: [
                            _automaticUpdates(
                              title: l.prototypeAutomaticUpdates,
                              value: value.subscriptionEnabled,
                              onChanged: state.saving
                                  ? null
                                  : controller.updateSubscriptionEnabled,
                            ),
                            _interval(
                              l,
                              value.subscriptionInterval,
                              value.subscriptionEnabled && !state.saving,
                              controller.updateSubscriptionInterval,
                            ),
                          ],
                        ),
                        SettingSection(
                          title: l.prototypeRoutingData,
                          icon: LucideIcons.globe2,
                          padding: EdgeInsets.zero,
                          dividerIndent: 0,
                          description: l.prototypeGeodataUpdatesTogether,
                          descriptionBelow: true,
                          children: [
                            _automaticUpdates(
                              title: l.prototypeAutomaticUpdates,
                              value: value.geoDataEnable,
                              onChanged: state.saving
                                  ? null
                                  : controller.updateGeoDataEnable,
                            ),
                            _interval(
                              l,
                              value.geoDataInterval,
                              value.geoDataEnable && !state.saving,
                              controller.updateGeoDataInterval,
                            ),
                          ],
                        ),
                        _note(context, l.prototypeUpdateTimingNotice),
                        _note(context, l.prototypeDueUpdatesRetryNotice),
                        SettingSection(
                          title: l.prototypeDownloadCompatibility,
                          icon: LucideIcons.globe2,
                          padding: EdgeInsets.zero,
                          dividerIndent: 0,
                          description: l.prototypeDownloadCompatibilityHint,
                          descriptionBelow: true,
                          children: [
                            SettingRow(
                              title: 'User-Agent',
                              titleStyle: AppTypography.settingsRow,
                              minHeight: 62,
                              contentPadding:
                                  const EdgeInsetsDirectional.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                              trailing: SettingSelect<DownloadUserAgentMode>(
                                value: state.userAgent,
                                entries: {
                                  DownloadUserAgentMode.oneXray: 'OneXray',
                                  DownloadUserAgentMode.system:
                                      l.prototypeSystemBrowser,
                                },
                                onChanged: state.saving
                                    ? null
                                    : controller.updateUserAgent,
                              ),
                            ),
                          ],
                        ),
                        if (state.failed)
                          Text(
                            l.prototypeTemporarilyUnavailable,
                            style: AppTypography.settingsDetailNote.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        );
      },
    ),
  );

  Widget _automaticUpdates({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) => SettingRow(
    title: title,
    titleStyle: AppTypography.settingsRow,
    minHeight: 58,
    contentPadding: const EdgeInsetsDirectional.symmetric(
      horizontal: 13,
      vertical: 7,
    ),
    enabled: onChanged != null,
    onTap: onChanged == null ? null : () => onChanged(!value),
    trailing: ShadSwitch(
      value: value,
      enabled: onChanged != null,
      onChanged: onChanged,
    ),
  );

  Widget _note(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      text,
      style: AppTypography.settingsDetailNote.copyWith(
        color: ColorManager.secondaryText(context),
      ),
    ),
  );

  Widget _interval(
    AppLocalizations l,
    AutoUpdateInterval value,
    bool enabled,
    ValueChanged<AutoUpdateInterval?> onChanged,
  ) => SettingRow(
    title: l.prototypeUpdateInterval,
    titleStyle: AppTypography.settingsRow,
    minHeight: 62,
    contentPadding: const EdgeInsetsDirectional.symmetric(
      horizontal: 14,
      vertical: 10,
    ),
    trailing: SettingSelect<AutoUpdateInterval>(
      value: value,
      entries: {
        AutoUpdateInterval.oneDay: l.prototypeEveryDay,
        AutoUpdateInterval.threeDays: l.prototypeEveryThreeDays,
        AutoUpdateInterval.oneWeek: l.prototypeEveryWeek,
      },
      onChanged: enabled ? onChanged : null,
    ),
  );
}
