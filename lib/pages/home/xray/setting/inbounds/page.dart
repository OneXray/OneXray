import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/inbounds/controller.dart';
import 'package:onexray/pages/home/xray/setting/inbounds/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class InboundsPage extends StatefulWidget {
  final InboundsParams params;

  const InboundsPage({super.key, required this.params});

  @override
  State<InboundsPage> createState() => _InboundsPageState();
}

class _InboundsPageState extends State<InboundsPage> {
  late final InboundsController controller;

  @override
  void initState() {
    super.initState();
    controller = InboundsController(widget.params);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.inboundsPageTitle),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(child: SingleChildScrollView(child: _editSection(context))),
          _bottomButton(context),
        ],
      ),
    );
  }

  Widget _editSection(BuildContext context) {
    return SettingSection(
      title: "",
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.inboundsPageTun,
          onTap: () => controller.editTun(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.inboundsPagePing,
          onTap: () => controller.editPing(context),
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
