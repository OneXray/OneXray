import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/outbounds/controller.dart';
import 'package:onexray/pages/home/xray/setting/outbounds/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

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
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    OutboundsController controller,
    OutboundsCubitState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _chainProxySection(context, controller, state),
                    _editSection(context, controller),
                  ],
                ),
              ),
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _chainProxySection(
    BuildContext context,
    OutboundsController controller,
    OutboundsCubitState state,
  ) {
    final chainProxy = state.outboundsState.chainProxy;
    final title =
        chainProxy?.name ??
        AppLocalizations.of(context)!.chainProxyPageDisabled;
    return SettingSection(
      title: AppLocalizations.of(context)!.chainProxyPageTitle,
      children: [
        NavigationSettingRow(
          title: title,
          onTap: () => controller.importChainProxy(context),
        ),
        if (chainProxy != null)
          SettingRow(
            title: AppLocalizations.of(context)!.chainProxyPageDelete,
            onTap: () => controller.deleteChainProxy(),
            trailing: const Icon(Icons.delete),
          ),
      ],
    );
  }

  Widget _editSection(BuildContext context, OutboundsController controller) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundsPageSystem,
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.outboundFreedomPageTitle,
          onTap: () => controller.editFreedom(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.outboundFragmentPageTitle,
          onTap: () => controller.editFragment(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.outboundBlackHolePageTitle,
          onTap: () => controller.editBlackHole(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.outboundDnsPageTitle,
          onTap: () => controller.editDns(context),
        ),
      ],
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
