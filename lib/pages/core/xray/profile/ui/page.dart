import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/xray/profile/ui/controller.dart';
import 'package:onexray/pages/core/xray/profile/ui/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class XrayProfileUIPage extends StatelessWidget {
  final XrayProfileUIParams params;

  const XrayProfileUIPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayProfileUIController(params),
      child: BlocBuilder<XrayProfileUIController, XrayProfileUIPageState>(
        builder: (context, state) {
          final controller = context.read<XrayProfileUIController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.xrayProfileUIPageTitle),
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

  Widget _body(BuildContext context, XrayProfileUIController controller) {
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
    XrayProfileUIController controller,
  ) {
    return SettingSection(title: "", children: [_name(context, controller)]);
  }

  Widget _name(BuildContext context, XrayProfileUIController controller) {
    return TextFieldSettingRow(
      controller: controller.nameController,
      label: AppLocalizations.of(context)!.xrayProfileUIPageName,
      hintText: AppLocalizations.of(context)!.xrayProfileUIPageName,
    );
  }

  Widget _editSection(
    BuildContext context,
    XrayProfileUIController controller,
  ) {
    return SettingSection(
      title: "",
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xrayProfileUIPageEditLog,
          value: controller.logSummary(context),
          onTap: () => controller.editLog(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xrayProfileUIPageEditDns,
          value: controller.dnsSummary(context),
          onTap: () => controller.editDns(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xrayProfileUIPageEditFakeDns,
          value: controller.fakeDnsSummary(context),
          valueMaxLines: 1,
          onTap: () => controller.editFakeDns(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xrayProfileUIPageEditRouting,
          value: controller.routingSummary(context),
          onTap: () => controller.editRouting(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xrayProfileUIPageEditInbounds,
          value: controller.inboundsSummary(context),
          onTap: () => controller.editInbounds(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xrayProfileUIPageEditOutbounds,
          value: controller.outboundsSummary(context),
          onTap: () => controller.editOutbounds(context),
        ),
      ],
    );
  }

  Widget _bottomButton(
    BuildContext context,
    XrayProfileUIController controller,
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
