import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/raw_edit/controller.dart';
import 'package:onexray/pages/home/xray/raw_edit/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';

class XrayRawEditPage extends StatefulWidget {
  final XrayRawEditParams params;

  const XrayRawEditPage({super.key, required this.params});

  @override
  State<XrayRawEditPage> createState() => _XrayRawEditPageState();
}

class _XrayRawEditPageState extends State<XrayRawEditPage> {
  late final XrayRawEditController controller;

  @override
  void initState() {
    super.initState();
    controller = XrayRawEditController(widget.params);
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
        title: Text(AppLocalizations.of(context)!.outboundPageTitle),
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
            child: TextField(
              controller: controller.controller,
              decoration: InputDecoration(border: InputBorder.none),
              maxLines: null,
            ),
          ),
          _bottomButton(context),
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
