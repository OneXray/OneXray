import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/inbounds/controller.dart';
import 'package:onexray/pages/home/xray/setting/inbounds/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class InboundsPage extends StatelessWidget {
  final InboundsParams params;

  const InboundsPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboundsController(params),
      child: Builder(
        builder: (context) {
          final controller = context.read<InboundsController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.inboundsPageTitle),
            ),
            body: SafeArea(child: _body(context, controller)),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, InboundsController controller) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: _editSection(context, controller),
              ),
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _editSection(BuildContext context, InboundsController controller) {
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

  Widget _bottomButton(BuildContext context, InboundsController controller) {
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
