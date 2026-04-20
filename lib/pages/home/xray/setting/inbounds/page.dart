import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/inbounds/controller.dart';
import 'package:onexray/pages/home/xray/setting/inbounds/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/section.dart';

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
    return SectionView(
      title: "",
      child: Column(
        children: [
          ListTile(
            onTap: () => controller.editTun(context),
            title: Text(AppLocalizations.of(context)!.inboundsPageTun),
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            onTap: () => controller.editPing(context),
            title: Text(AppLocalizations.of(context)!.inboundsPagePing),
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
