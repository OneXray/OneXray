import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/outbounds/controller.dart';
import 'package:onexray/pages/home/xray/setting/outbounds/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/section.dart';

class OutboundsPage extends StatelessWidget {
  final OutboundsParams params;

  const OutboundsPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboundsController(params),
      child: BlocBuilder<OutboundsController, OutboundsCubitState>(
        builder: (context, state) {
          final controller = context.read<OutboundsController>();
          return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.outboundsPageTitle),
        ),
        body: SafeArea(child: _body(context, controller)),
      );
        },
      ),
    );
  }

  Widget _body(BuildContext context, OutboundsController controller) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
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
    );
  }

  Widget _editSection(BuildContext context, OutboundsController controller) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundsPageSystem,
      child: Column(
        children: [
          ListTile(
            onTap: () => controller.editFreedom(context),
            title: Text(AppLocalizations.of(context)!.outboundFreedomPageTitle),
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            onTap: () => controller.editFragment(context),
            title: Text(
              AppLocalizations.of(context)!.outboundFragmentPageTitle,
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            onTap: () => controller.editBlackHole(context),
            title: Text(
              AppLocalizations.of(context)!.outboundBlackHolePageTitle,
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            onTap: () => controller.editDns(context),
            title: Text(AppLocalizations.of(context)!.outboundDnsPageTitle),
            trailing: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _bottomButton(BuildContext context, OutboundsController controller) {
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
