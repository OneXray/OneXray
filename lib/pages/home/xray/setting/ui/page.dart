import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/ui/controller.dart';
import 'package:onexray/pages/home/xray/setting/ui/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class XraySettingUIPage extends StatefulWidget {
  final XraySettingUIParams params;

  const XraySettingUIPage({super.key, required this.params});

  @override
  State<XraySettingUIPage> createState() => _XraySettingUIPageState();
}

class _XraySettingUIPageState extends State<XraySettingUIPage> {
  late final XraySettingUIController controller;

  @override
  void initState() {
    super.initState();
    controller = XraySettingUIController(
      widget.params,
      onChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ResponsiveContent(
                child: Column(
                  children: [_nameSection(context), _editSection(context)],
                ),
              ),
            ),
          ),
          _bottomButton(context),
        ],
      ),
    );
  }

  Widget _nameSection(BuildContext context) {
    return SettingSection(title: "", children: [_name(context)]);
  }

  Widget _name(BuildContext context) {
    return TextFieldSettingRow(
      controller: controller.nameController,
      label: AppLocalizations.of(context)!.xraySettingUIPageName,
      hintText: AppLocalizations.of(context)!.xraySettingUIPageName,
    );
  }

  Widget _editSection(BuildContext context) {
    return SettingSection(
      title: "",
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xraySettingUIPageEditLog,
          value: controller.logSummary(context),
          onTap: () => controller.editLog(context),
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.xraySettingUIPageStats,
          value: controller.statsSummary(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xraySettingUIPageMetrics,
          value: controller.metricsSummary(context),
          onTap: () => controller.showMetrics(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.xraySettingUIPagePolicy,
          value: controller.policySummary(context),
          onTap: () => controller.showPolicy(context),
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

  Widget _bottomButton(BuildContext context) {
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
