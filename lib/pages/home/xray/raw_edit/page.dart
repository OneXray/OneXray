import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/raw_edit/controller.dart';
import 'package:onexray/pages/home/xray/raw_edit/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';

class XrayRawEditPage extends StatelessWidget {
  final XrayRawEditParams params;

  const XrayRawEditPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayRawEditController(params),
      child: Builder(
        builder: (context) {
          final controller = context.read<XrayRawEditController>();
          return Scaffold(
            appBar: AppBar(title: Text(params.title)),
            body: SafeArea(child: _body(context, controller)),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, XrayRawEditController controller) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        desktopMaxWidth: 900,
        adaptiveBreakpoint: 840,
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: controller.controller,
                decoration: InputDecoration(border: InputBorder.none),
                maxLines: null,
              ),
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _bottomButton(BuildContext context, XrayRawEditController controller) {
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
