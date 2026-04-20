import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/ping/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/section.dart';
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
    );
  }

  Widget _section(
    BuildContext context,
    PingPageState state,
    PingController controller,
  ) {
    return SectionView(
      title: "",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _timeout(context, state, controller),
          _concurrency(context, state, controller),
          _url(context, state, controller),
          if (state.pingState.url == PingUrl.custom)
            _customUrl(context, controller)
          else
            _realUrl(context, state),
        ],
      ),
    );
  }

  Widget _timeout(
    BuildContext context,
    PingPageState state,
    PingController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.pingPageTimeout),
        Expanded(
          child: Slider(
            min: PingTimeout.min,
            max: PingTimeout.max,
            divisions: PingTimeout.divisions,
            label: state.pingState.timeout.round().toString(),
            value: state.pingState.timeout,
            onChanged: (value) => controller.updateTimeout(value),
          ),
        ),
      ],
    );
  }

  Widget _concurrency(
    BuildContext context,
    PingPageState state,
    PingController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.pingPageConcurrency),
        Expanded(
          child: Slider(
            min: PingConcurrency.min,
            max: PingConcurrency.max,
            divisions: PingConcurrency.divisions,
            label: state.pingState.concurrency.round().toString(),
            value: state.pingState.concurrency,
            onChanged: (value) => controller.updateConcurrency(value),
          ),
        ),
      ],
    );
  }

  Widget _url(
    BuildContext context,
    PingPageState state,
    PingController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.pingPageUrl),
        TextMenuPicker(
          title: state.pingState.url.name,
          selections: PingUrl.names,
          callback: (value) => controller.updateUrl(value),
        ),
      ],
    );
  }

  Widget _realUrl(BuildContext context, PingPageState state) {
    return Text(
      state.pingState.url.url,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  Widget _customUrl(BuildContext context, PingController controller) {
    return TextField(
      controller: controller.customUrlController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.pingPageUrl),
        hintText: AppLocalizations.of(context)!.pingPageUrl,
      ),
    );
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
