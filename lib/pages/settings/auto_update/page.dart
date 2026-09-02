import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/auto_update/controller.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/auto_update/state.dart';

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
        return Scaffold(
          appBar: AppBar(title: Text(l.prototypeDataUpdates)),
          bottomNavigationBar: PageActionBar(
            children: [
              TextButton(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(l.prototypeDataUpdateIntervalsHint),
                        ),
                        SettingSection(
                          title: l.prototypeSubscriptions,
                          description: l.prototypeSubscriptionUpdateGuard,
                          children: [
                            SwitchListTile(
                              title: Text(l.prototypeAutomaticUpdates),
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
                          description: l.prototypeGeodataUpdatesTogether,
                          children: [
                            SwitchListTile(
                              title: Text(l.prototypeAutomaticUpdates),
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
                        SettingSection(
                          title: l.prototypeDownloadCompatibility,
                          description: l.prototypeDownloadCompatibilityHint,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child:
                                  DropdownButtonFormField<
                                    DownloadUserAgentMode
                                  >(
                                    initialValue: state.userAgent,
                                    decoration: const InputDecoration(
                                      labelText: 'User-Agent',
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: DownloadUserAgentMode.oneXray,
                                        child: Text('OneXray'),
                                      ),
                                      DropdownMenuItem(
                                        value: DownloadUserAgentMode.system,
                                        child: Text(l.prototypeSystemBrowser),
                                      ),
                                    ],
                                    onChanged: state.saving
                                        ? null
                                        : controller.updateUserAgent,
                                  ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(l.prototypeUpdateTimingNotice),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(l.prototypeDueUpdatesRetryNotice),
                        ),
                        if (state.failed)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              l.prototypeTemporarilyUnavailable,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
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

  Widget _interval(
    AppLocalizations l,
    AutoUpdateInterval value,
    bool enabled,
    ValueChanged<AutoUpdateInterval?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.all(16),
    child: DropdownButtonFormField<AutoUpdateInterval>(
      initialValue: value,
      decoration: InputDecoration(labelText: l.prototypeUpdateInterval),
      items: [
        DropdownMenuItem(
          value: AutoUpdateInterval.oneDay,
          child: Text(l.prototypeEveryDay),
        ),
        DropdownMenuItem(
          value: AutoUpdateInterval.threeDays,
          child: Text(l.prototypeEveryThreeDays),
        ),
        DropdownMenuItem(
          value: AutoUpdateInterval.oneWeek,
          child: Text(l.prototypeEveryWeek),
        ),
      ],
      onChanged: enabled ? onChanged : null,
    ),
  );
}
