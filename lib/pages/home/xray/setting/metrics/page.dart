import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/metrics/controller.dart';
import 'package:onexray/pages/home/xray/setting/metrics/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class MetricsPage extends StatelessWidget {
  final MetricsParams params;

  const MetricsPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MetricsController(params),
      child: BlocBuilder<MetricsController, MetricsCubitState>(
        builder: (context, state) {
          final controller = context.read<MetricsController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.metricsPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    MetricsController controller,
    MetricsCubitState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ResponsiveContent(
                child: SettingSection(
                  title: "",
                  children: [
                    SwitchSettingRow(
                      title: AppLocalizations.of(context)!.metricsPageEnabled,
                      value: state.metricsState.enabled,
                      onChanged: controller.updateEnabled,
                    ),
                    SettingRow(
                      title: AppLocalizations.of(context)!.metricsPageListen,
                      value: controller.listenValue(context),
                      enabled: controller.listenRowEnabled,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _bottomButton(BuildContext context, MetricsController controller) {
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
