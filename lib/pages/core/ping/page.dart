import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/ping/controller.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PingPage extends StatelessWidget {
  const PingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PingController(),
      child: BlocBuilder<PingController, PingPageState>(
        builder: (context, state) {
          final controller = context.read<PingController>();
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.pingPageTitle,
            saveLabel: localizations.buttonSave,
            onSave: () => controller.save(context),
            body: _body(context, state, controller),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    PingPageState state,
    PingController controller,
  ) {
    return SettingsPageScroll(
      desktopMaxWidth: 920,
      child: _section(context, state, controller),
    );
  }

  Widget _section(
    BuildContext context,
    PingPageState state,
    PingController controller,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.pingPageTitle,
      description: AppLocalizations.of(context)!.pingPageDescription,
      children: [
        _timeout(context, state, controller),
        _concurrency(context, state, controller),
        _url(context, state, controller),
        _realUrl(context, state),
        _autoPingNewConfigs(context, state, controller),
      ],
    );
  }

  Widget _autoPingNewConfigs(
    BuildContext context,
    PingPageState state,
    PingController controller,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.pingPageAutoPingNewConfigs,
      subtitle: AppLocalizations.of(
        context,
      )!.pingPageAutoPingNewConfigsDescription,
      leading: const Icon(LucideIcons.wifi),
      value: state.pingState.autoPingNewConfigs,
      onChanged: (value) => controller.updateAutoPingNewConfigs(value),
    );
  }

  Widget _timeout(
    BuildContext context,
    PingPageState state,
    PingController controller,
  ) {
    return SliderSettingRow(
      title: AppLocalizations.of(context)!.pingPageTimeout,
      subtitle: AppLocalizations.of(context)!.pingPageTimeoutDescription,
      leading: const Icon(LucideIcons.activity),
      min: PingTimeout.min,
      max: PingTimeout.max,
      divisions: PingTimeout.divisions,
      label: "${state.pingState.timeout.round()}s",
      value: state.pingState.timeout,
      onChanged: (value) => controller.updateTimeout(value),
    );
  }

  Widget _concurrency(
    BuildContext context,
    PingPageState state,
    PingController controller,
  ) {
    return SliderSettingRow(
      title: AppLocalizations.of(context)!.pingPageConcurrency,
      subtitle: AppLocalizations.of(context)!.pingPageConcurrencyDescription,
      leading: const Icon(LucideIcons.slidersHorizontal),
      min: PingConcurrency.min,
      max: PingConcurrency.max,
      divisions: PingConcurrency.divisions,
      label: state.pingState.concurrency.round().toString(),
      value: state.pingState.concurrency,
      onChanged: (value) => controller.updateConcurrency(value),
    );
  }

  Widget _url(
    BuildContext context,
    PingPageState state,
    PingController controller,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.pingPageUrl,
      leading: const Icon(LucideIcons.globe2),
      value: state.pingState.url.name,
      selections: PingUrl.names,
      onSelected: (value) => controller.updateUrl(value),
    );
  }

  Widget _realUrl(BuildContext context, PingPageState state) {
    return SettingRow(
      title: AppLocalizations.of(context)!.pingPageResolvedUrl,
      subtitle: state.pingState.url.url,
      leading: const Icon(LucideIcons.link),
      onTap: () => context.read<PingController>().copyResolvedUrl(context),
      trailing: const Icon(LucideIcons.copy),
    );
  }
}
