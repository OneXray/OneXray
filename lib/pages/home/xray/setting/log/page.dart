import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/log/controller.dart';
import 'package:onexray/pages/home/xray/setting/log/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/xray/setting/log_state.dart';

class XrayLogPage extends StatelessWidget {
  final XrayLogParams params;

  const XrayLogPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayLogController(params),
      child: BlocBuilder<XrayLogController, XrayLogCubitState>(
        builder: (context, state) {
          final controller = context.read<XrayLogController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.xrayLogPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    XrayLogController controller,
    XrayLogCubitState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: _settingSection(context, controller, state),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _settingSection(
    BuildContext context,
    XrayLogController controller,
    XrayLogCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        SelectSettingRow(
          title: AppLocalizations.of(context)!.xrayLogPageLogLevel,
          value: state.logState.logLevel.name,
          selections: XrayLogLevel.names,
          onSelected: (value) => controller.updateLogLevel(value),
        ),
        SwitchSettingRow(
          title: AppLocalizations.of(context)!.xrayLogPageDnsLog,
          value: state.logState.dnsLog,
          onChanged: (value) => controller.updateDnsLog(value),
        ),
        SelectSettingRow(
          title: AppLocalizations.of(context)!.xrayLogPageMaskAddress,
          value: state.logState.maskAddress.name,
          selections: XrayLogMaskAddress.names,
          onSelected: (value) => controller.updateMaskAddress(value),
        ),
      ],
    );
  }

  Widget _bottomButton(BuildContext context, XrayLogController controller) {
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
