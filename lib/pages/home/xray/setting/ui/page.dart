import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/ui/controller.dart';
import 'package:onexray/pages/home/xray/setting/ui/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/section.dart';

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
    controller = XraySettingUIController(widget.params);
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
              child: Column(
                children: [
                  _nameSection(context),
                  _editSection(context),
                ],
              ),
            ),
          ),
          _bottomButton(context),
        ],
      ),
    );
  }

  Widget _nameSection(BuildContext context) {
    return SectionView(title: "", child: _name(context));
  }

  Widget _name(BuildContext context) {
    return TextField(
      controller: controller.nameController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.xraySettingUIPageName),
        hintText: AppLocalizations.of(context)!.xraySettingUIPageName,
      ),
    );
  }

  Widget _editSection(BuildContext context) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          ListTile(
            onTap: () => controller.editLog(context),
            title: Text(AppLocalizations.of(context)!.xraySettingUIPageEditLog),
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            onTap: () => controller.editDns(context),
            title: Text(AppLocalizations.of(context)!.xraySettingUIPageEditDns),
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            onTap: () => controller.editRouting(context),
            title: Text(AppLocalizations.of(context)!.xraySettingUIPageEditRouting),
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            onTap: () => controller.editInbounds(context),
            title: Text(AppLocalizations.of(context)!.xraySettingUIPageEditInbounds),
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            onTap: () => controller.editOutbounds(context),
            title: Text(AppLocalizations.of(context)!.xraySettingUIPageEditOutbounds),
            trailing: const Icon(Icons.chevron_right),
          ),
        ],
      ),
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
