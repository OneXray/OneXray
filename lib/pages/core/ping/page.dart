import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/ping/controller.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/ping/state.dart';

class PingPage extends StatelessWidget {
  const PingPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PingController(),
    child: BlocBuilder<PingController, PingPageState>(
      builder: (context, state) {
        final controller = context.read<PingController>();
        final l = AppLocalizations.of(context)!;
        final value = state.pingState;
        return Scaffold(
          appBar: AppBar(title: Text(l.prototypeSpeedTest)),
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
                          child: Text(l.prototypeSpeedTestHint),
                        ),
                        SettingSection(
                          title: l.prototypeTimeout,
                          description: l.prototypeTimeoutHint,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    l.prototypeSeconds(value.timeout.round()),
                                  ),
                                  Slider(
                                    min: PingTimeout.min,
                                    max: PingTimeout.max,
                                    divisions: PingTimeout.divisions,
                                    value: value.timeout,
                                    label: l.prototypeSeconds(
                                      value.timeout.round(),
                                    ),
                                    onChanged: state.saving
                                        ? null
                                        : controller.updateTimeout,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SettingSection(
                          title: l.prototypeSpeedTestUrl,
                          description: l.prototypeSpeedTestUrlHint,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    initialValue: value.url.name,
                                    decoration: InputDecoration(
                                      labelText: l.prototypeSpeedTestUrl,
                                    ),
                                    items: [
                                      for (final option in PingUrl.values)
                                        DropdownMenuItem(
                                          value: option.name,
                                          child: Text(
                                            option == PingUrl.custom
                                                ? l.prototypeCustomUrl
                                                : option.name,
                                          ),
                                        ),
                                    ],
                                    onChanged: state.saving
                                        ? null
                                        : (value) {
                                            if (value != null) {
                                              controller.updateUrl(value);
                                            }
                                          },
                                  ),
                                  const SizedBox(height: 16),
                                  if (value.url == PingUrl.custom)
                                    TextField(
                                      controller:
                                          controller.customUrlController,
                                      enabled: !state.saving,
                                      textDirection: TextDirection.ltr,
                                      keyboardType: TextInputType.url,
                                      autocorrect: false,
                                      decoration: InputDecoration(
                                        labelText: l.prototypeCustomUrl,
                                      ),
                                    )
                                  else
                                    SelectableText(
                                      value.realUrl,
                                      textDirection: TextDirection.ltr,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(l.prototypeSpeedTestSavedNotice),
                        ),
                        if (state.error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
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
}
