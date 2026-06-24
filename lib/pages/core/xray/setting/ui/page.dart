import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/xray/setting/ui/controller.dart';
import 'package:onexray/pages/core/xray/setting/ui/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class XraySettingUIPage extends StatelessWidget {
  final XraySettingUIParams params;

  const XraySettingUIPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XraySettingUIController(params),
      child: BlocBuilder<XraySettingUIController, XraySettingUICubitState>(
        builder: (context, state) {
          final controller = context.read<XraySettingUIController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.xraySettingUIPageTitle),
              actions: [
                IconButton(
                  onPressed: () => controller.gotoRawEdit(context),
                  icon: Icon(Icons.edit),
                ),
              ],
            ),
            body: SafeArea(child: _body(context, controller)),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, XraySettingUIController controller) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ResponsiveContent(
                child: Column(
                  children: [
                    _nameSection(context, controller),
                    _editSection(context, controller),
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

  Widget _nameSection(
    BuildContext context,
    XraySettingUIController controller,
  ) {
    return SettingSection(title: "", children: [_name(context, controller)]);
  }

  Widget _name(BuildContext context, XraySettingUIController controller) {
    return TextFieldSettingRow(
      controller: controller.nameController,
      label: AppLocalizations.of(context)!.xraySettingUIPageName,
      hintText: AppLocalizations.of(context)!.xraySettingUIPageName,
    );
  }

  Widget _editSection(
    BuildContext context,
    XraySettingUIController controller,
  ) {
    return SettingSection(
      title: "",
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xraySettingUIPageEditLog,
          value: controller.logSummary(context),
          onTap: () => controller.editLog(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xraySettingUIPageEditDns,
          value: controller.dnsSummary(context),
          onTap: () => controller.editDns(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xraySettingUIPageEditFakeDns,
          value: controller.fakeDnsSummary(context),
          valueMaxLines: 1,
          onTap: () => controller.editFakeDns(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xraySettingUIPageEditRouting,
          value: controller.routingSummary(context),
          onTap: () => controller.editRouting(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xraySettingUIPageEditInbounds,
          value: controller.inboundsSummary(context),
          onTap: () => controller.editInbounds(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xraySettingUIPageEditOutbounds,
          value: controller.outboundsSummary(context),
          onTap: () => controller.editOutbounds(context),
        ),
      ],
    );
  }

  Widget _bottomButton(
    BuildContext context,
    XraySettingUIController controller,
  ) {
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
