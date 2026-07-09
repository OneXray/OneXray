import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/full_config/controller.dart';
import 'package:onexray/pages/core/xray/full_config/params.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class XrayFullConfigPage extends StatelessWidget {
  final XrayFullConfigParams params;

  const XrayFullConfigPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayFullConfigController(params),
      child: BlocBuilder<XrayFullConfigController, XrayFullConfigPageState>(
        builder: (context, state) {
          final controller = context.read<XrayFullConfigController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.xrayFullConfigTitle),
              actions: [
                IconButton(
                  onPressed: () => controller.gotoRawEdit(context),
                  icon: const Icon(Icons.edit),
                ),
              ],
            ),
            body: SafeArea(child: _body(context, controller)),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, XrayFullConfigController controller) {
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
    XrayFullConfigController controller,
  ) {
    return SettingSection(title: "", children: [_name(context, controller)]);
  }

  Widget _name(BuildContext context, XrayFullConfigController controller) {
    return TextFieldSettingRow(
      controller: controller.nameController,
      label: AppLocalizations.of(context)!.xrayProfileUIPageName,
      hintText: AppLocalizations.of(context)!.xrayProfileUIPageName,
    );
  }

  Widget _editSection(
    BuildContext context,
    XrayFullConfigController controller,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: "",
      children: [
        NavigationSettingRow(
          title: localizations.xrayProfileUIPageEditOutbounds,
          value: controller.outboundsSummary(context),
          onTap: () => controller.editOutbounds(context),
        ),
        NavigationSettingRow(
          title: localizations.xrayProfileUIPageEditRouting,
          value: controller.routingSummary(context),
          onTap: () => controller.editRouting(context),
        ),
        NavigationSettingRow(
          title: localizations.xrayProfileUIPageEditDns,
          value: controller.dnsSummary(context),
          onTap: () => controller.editDns(context),
        ),
      ],
    );
  }

  Widget _bottomButton(
    BuildContext context,
    XrayFullConfigController controller,
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
