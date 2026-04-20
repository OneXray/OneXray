import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/outbound_freedom/controller.dart';
import 'package:onexray/pages/home/xray/setting/outbound_freedom/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/pages/widget/text_row.dart';

class OutboundFreedomPage extends StatelessWidget {
  final OutboundFreedomParams params;

  const OutboundFreedomPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboundFreedomController(params),
      child: BlocBuilder<OutboundFreedomController, OutboundFreedomCubitState>(
        builder: (context, state) {
          final controller = context.read<OutboundFreedomController>();
          return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.outboundFreedomPageTitle),
        ),
        body: SafeArea(child: _body(context, controller, state)),
      );
        },
      ),
    );
  }

  Widget _body(BuildContext context, OutboundFreedomController controller, OutboundFreedomCubitState state) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _protocolSection(context, controller, state),
                  if (AppPlatform.isLinux || AppPlatform.isWindows)
                    _sockoptSection(context, controller, state),
                ],
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _protocolSection(
    BuildContext context,
    OutboundFreedomController controller, OutboundFreedomCubitState state) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          TextRow(
            title: AppLocalizations.of(context)!.outboundFreedomPageProtocol,
            detail: state.freedomState.protocol.name,
          ),
          TextRow(
            title: AppLocalizations.of(context)!.outboundFreedomPageTag,
            detail: state.freedomState.tag.name,
          ),
        ],
      ),
    );
  }

  Widget _sockoptSection(
    BuildContext context,
    OutboundFreedomController controller, OutboundFreedomCubitState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundFreedomPageSockopt,
      child: Column(children: [_interface(context, controller, state)]),
    );
  }

  Widget _interface(
    BuildContext context,
    OutboundFreedomController controller, OutboundFreedomCubitState state) {
    return InkWell(
      onTap: () => controller.editInterface(context),
      child: TextRow(
        title: AppLocalizations.of(context)!.outboundFreedomPageInterface,
        detail: state.freedomState.interface,
      ),
    );
  }

  Widget _bottomButton(
    BuildContext context,
    OutboundFreedomController controller,
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
