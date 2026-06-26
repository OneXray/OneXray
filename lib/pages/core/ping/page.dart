import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/ping/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/ping/state.dart';

class PingPage extends StatelessWidget {
  const PingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PingController(),
      child: BlocBuilder<PingController, PingPageState>(
        builder: (context, state) {
          final controller = context.read<PingController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.pingPageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
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
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: _section(context, state, controller),
              ),
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    PingPageState state,
    PingController controller,
  ) {
    return SettingSection(
      title: "",
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
      min: PingTimeout.min,
      max: PingTimeout.max,
      divisions: PingTimeout.divisions,
      label: state.pingState.timeout.round().toString(),
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
      value: state.pingState.url.name,
      selections: PingUrl.names,
      onSelected: (value) => controller.updateUrl(value),
    );
  }

  Widget _realUrl(BuildContext context, PingPageState state) {
    return SettingRow(title: state.pingState.url.url, titleMaxLines: 3);
  }

  Widget _bottomButton(BuildContext context, PingController controller) {
    return BottomView(
      child: Row(
        children: [
          Expanded(
            child: PrimaryBottomButton(
              title: AppLocalizations.of(context)!.buttonSave,
              callback: () => controller.save(context),
            ),
          ),
        ],
      ),
    );
  }
}
